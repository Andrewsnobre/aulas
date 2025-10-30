// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GuessTheSecretNumberChallenge {
 
    bytes32 public constant ANSWER_HASH = 0x0f040e7390ff8988af76b6b3c3213ce02cd16af45cbadbc01b0cec05c0931e85;

    constructor() payable {
        require(msg.value == 1 ether, "constructor requires 1 ETH");
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) external payable {
        require(msg.value == 1 ether, "must send 1 ETH to guess");

        // em 0.8.x usamos abi.encodePacked para compor bytes antes de keccak256
        if (keccak256(abi.encodePacked(n)) == ANSWER_HASH) {
            // transfer pode falhar por limitação de gás; padrão moderno é usar call
            (bool sent, ) = payable(msg.sender).call{value: 2 ether}("");
            require(sent, "transfer failed");
        }
    }

    // função para receber ETH (opcional)
    receive() external payable {}
}
