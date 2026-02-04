// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amt) external returns (bool);
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
    function approve(address spender, uint256 amt) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IPriceOracle {
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint8);
}

library Sig {
    function recover(bytes32 digest, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "siglen");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
        if (v < 27) v += 27;
        return ecrecover(digest, v, r, s);
    }
}

contract TrainingToken {
    string public name = "TrainingToken";
    string public symbol = "TRN";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amt);
    event Approval(address indexed owner, address indexed spender, uint256 amt);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        _mint(msg.sender, 1_000_000e18);
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        _transfer(msg.sender, to, amt);
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "allow");
        unchecked {
            allowance[from][msg.sender] = a - amt;
        }
        _transfer(from, to, amt);
        return true;
    }

    function mint(address to, uint256 amt) external onlyOwner {
        _mint(to, amt);
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function _transfer(address from, address to, uint256 amt) internal {
        require(to != address(0), "to=0");
        uint256 b = balanceOf[from];
        require(b >= amt, "bal");
        unchecked {
            balanceOf[from] = b - amt;
            balanceOf[to] += amt;
        }
        emit Transfer(from, to, amt);
    }

    function _mint(address to, uint256 amt) internal {
        require(to != address(0), "to=0");
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }
}

contract MegaVault {
    IERC20 public immutable token;

    address public owner;
    bool public initialized;
    address public guardian;
    IPriceOracle public oracle;
    bool public paused;

    mapping(address => uint256) public shares;
    uint256 public totalShares;

    uint256 public treasuryFeeBps = 50;
    address public treasury;

    event Initialized(address indexed owner, address indexed guardian, address treasury);
    event Deposit(address indexed user, uint256 amount, uint256 mintedShares);
    event Withdraw(address indexed user, uint256 burnedShares, uint256 amountOut);
    event Paused(bool p);
    event OracleSet(address oracle);
    event FeeSet(uint256 bps);
    event TreasurySet(address t);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyGuardianOrOwner() {
        require(msg.sender == owner || msg.sender == guardian, "not auth");
        _;
    }

    modifier notPaused() {
        require(!paused, "paused");
        _;
    }

    constructor(IERC20 _token) {
        token = _token;
    }

    function initialize(address _owner, address _guardian, address _treasury, address _oracle) external {
        require(!initialized, "already");
        owner = _owner;
        guardian = _guardian;
        treasury = _treasury;
        oracle = IPriceOracle(_oracle);
        initialized = true;
        emit Initialized(_owner, _guardian, _treasury);
    }

    function setPaused(bool p) external onlyGuardianOrOwner {
        paused = p;
        emit Paused(p);
    }

    function setOracle(address o) external onlyOwner {
        oracle = IPriceOracle(o);
        emit OracleSet(o);
    }

    function setTreasury(address t) external onlyOwner {
        treasury = t;
        emit TreasurySet(t);
    }

    function setFeeBps(uint256 bps) external onlyOwner {
        treasuryFeeBps = bps;
        emit FeeSet(bps);
    }

    function deposit(uint256 amount) external notPaused {
        require(amount > 0, "amount=0");
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "tf");
        shares[msg.sender] += amount;
        totalShares += amount;
        emit Deposit(msg.sender, amount, amount);
    }

    function withdraw(uint256 shareAmount) external notPaused {
        require(shareAmount > 0, "share=0");
        uint256 s = shares[msg.sender];
        require(s >= shareAmount, "shares");

        uint256 fee = _calcFee(shareAmount);

        shares[msg.sender] = s - shareAmount;
        totalShares -= shareAmount;

        if (fee > 0 && treasury != address(0)) {
            token.transfer(treasury, fee);
        }

        uint256 out = shareAmount - fee;
        token.transfer(msg.sender, out);

        emit Withdraw(msg.sender, shareAmount, out);
    }

    function _calcFee(uint256 amount) internal view returns (uint256) {
        uint256 base = (amount * treasuryFeeBps) / 10_000;
        int256 p = oracle.latestAnswer();
        uint8 d = oracle.decimals();

        uint256 pu = uint256(p);
        if (d < 18) pu = pu * (10 ** (18 - d));
        if (d > 18) pu = pu / (10 ** (d - 18));

        uint256 adj = base + (base * pu) / 1e20;
        return adj;
    }
}

contract BadgeMinter {
    string public name = "TrainingBadge";
    string public symbol = "TBAD";

    address public owner;
    bool public paused;
    uint256 public price = 0.005 ether;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;

    event Mint(address indexed to, uint256 indexed tokenId, uint256 paid);
    event PriceSet(uint256 p);
    event Paused(bool p);
    event OwnerSet(address o);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address o) external onlyOwner {
        owner = o;
        emit OwnerSet(o);
    }

    function setPrice(uint256 p) external onlyOwner {
        price = p;
        emit PriceSet(p);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function mint(address to, uint256 tokenId) external payable {
        require(!paused, "paused");
        require(msg.value >= price, "pay");
        ownerOf[tokenId] = to;
        balanceOf[to] += 1;
        emit Mint(to, tokenId, msg.value);
    }

    receive() external payable {}
}

contract Airdropper {
    IERC20 public immutable token;
    address public signer;

    mapping(address => bool) public claimed;

    event Claimed(address indexed user, uint256 amount);
    event SignerSet(address s);

    constructor(IERC20 _token, address _signer) {
        token = _token;
        signer = _signer;
    }

    function setSigner(address s) external {
        signer = s;
        emit SignerSet(s);
    }

    function claim(uint256 amount, bytes calldata sig) external {
        require(!claimed[msg.sender], "claimed");
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, amount));
        address rec = Sig.recover(digest, sig);
        require(rec == signer, "bad sig");

        claimed[msg.sender] = true;
        token.transfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }
}

contract Treasury {
    address public owner;
    address public operator;
    bool public paused;

    event OwnerSet(address o);
    event OperatorSet(address op);
    event Paid(address indexed to, uint256 amount);
    event Paused(bool p);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyOperatorOrOwner() {
        require(msg.sender == owner || msg.sender == operator, "not auth");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address o) external onlyOwner {
        owner = o;
        emit OwnerSet(o);
    }

    function setOperator(address op) external onlyOwner {
        operator = op;
        emit OperatorSet(op);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function payBatch(address payable[] calldata tos, uint256[] calldata amts) external onlyOperatorOrOwner {
        require(!paused, "paused");
        require(tos.length == amts.length, "len");

        for (uint256 i = 0; i < tos.length; i++) {
            (bool success, ) = tos[i].call{value: amts[i]}("");
            require(success, "Transfer failed");
            emit Paid(tos[i], amts[i]);
        }
    }

    receive() external payable {}
}

contract MegaRouter {
    address public owner;
    bool public paused;

    event OwnerSet(address o);
    event Paused(bool p);
    event Executed(address indexed target, uint256 value, bytes data, bytes ret);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address o) external onlyOwner {
        owner = o;
        emit OwnerSet(o);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bytes memory) {
        require(!paused, "paused");
        require(target != address(0), "target=0");

        (bool ok, bytes memory ret) = target.call{value: value}(data);
        require(ok, "exec fail");
        emit Executed(target, value, data, ret);
        return ret;
    }

    function multicall(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        payable
        returns (bytes[] memory rets)
    {
        require(!paused, "paused");
        require(targets.length == datas.length && targets.length == values.length, "len");

        rets = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (bool ok, bytes memory ret) = targets[i].call{value: values[i]}(datas[i]);
            require(ok, "call fail");
            rets[i] = ret;
            emit Executed(targets[i], values[i], datas[i], ret);
        }
    }

    function execDelegate(address plugin, bytes calldata data) external returns (bytes memory) {
        require(!paused, "paused");
        (bool ok, bytes memory ret) = plugin.delegatecall(data);
        require(ok, "delegate fail");
        return ret;
    }

    receive() external payable {}
}
