

````md
# 📋 Relatório de Auditoria de Smart Contract  
## Projeto: AuditMintNFT  
**Contexto:** Contrato educacional para ensino de auditoria em Solidity  
**Ferramentas:** Análise manual + Foundry  
**Versões analisadas:**  
- ❌ AuditMintNFT (vulnerável)  
- ✅ AuditMintNFTFixed (corrigido)  

---

## 1️⃣ Visão Geral

Este relatório compara uma versão **intencionalmente vulnerável** de um contrato NFT com sua versão **corrigida**, destacando falhas comuns encontradas em auditorias reais e as boas práticas usadas para corrigi-las.

---

## 2️⃣ Vulnerabilidades Identificadas e Correções

---

## 🔴 VULN-01 — Ownership Takeover via `initialize()`

### ❌ Código Vulnerável
```solidity
function initialize(address _owner) external {
    require(!initialized, "already initialized");
    owner = _owner;
    // BUG: initialized nunca é setado
}
````

### ✅ Código Corrigido

```solidity
function initialize(address _owner) external {
    require(!initialized, "already initialized");
    require(_owner != address(0), "owner=0");
    initialized = true;

    owner = _owner;
}
```

### 📌 Explicação

Sem marcar `initialized = true`, qualquer pessoa poderia chamar `initialize()` novamente e assumir o controle do contrato.

---

## 🔴 VULN-02 — Controle de Acesso usando `tx.origin`

### ❌ Código Vulnerável

```solidity
modifier onlyOwner() {
    require(tx.origin == owner, "not owner");
    _;
}
```

### ✅ Código Corrigido

```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "not owner");
    _;
}
```

### 📌 Explicação

`tx.origin` permite ataques de phishing via contratos intermediários.
**Nunca deve ser usado para autenticação.**

---

## 🔴 VULN-03 — Mint sem Controle de Acesso (ACL)

### ❌ Código Vulnerável

```solidity
function mint(address to, uint256 tokenId) external payable {
    require(msg.value >= mintPrice, "pay more");
    ownerOf[tokenId] = to;
}
```

### ✅ Código Corrigido

```solidity
modifier onlyMinter() {
    require(msg.sender == owner || isMinter[msg.sender], "not minter");
    _;
}

function mint(address to, uint256 tokenId)
    external
    payable
    onlyMinter
{
    ...
}
```

### 📌 Explicação

Qualquer usuário podia emitir NFTs arbitrariamente, quebrando totalmente o modelo econômico.

---

## 🔴 VULN-04 — Sobrescrita de Token Existente

### ❌ Código Vulnerável

```solidity
ownerOf[tokenId] = to;
```

### ✅ Código Corrigido

```solidity
require(ownerOf[tokenId] == address(0), "already minted");
ownerOf[tokenId] = to;
```

### 📌 Explicação

Sem validação, um atacante poderia roubar NFTs sobrescrevendo o dono.

---

## 🔴 VULN-05 — DoS por Loop + `transfer()`

### ❌ Código Vulnerável

```solidity
function refundAll() external onlyOwner {
    for (uint256 i = 0; i < buyers.length; i++) {
        buyers[i].transfer(mintPrice);
    }
}
```

### ✅ Código Corrigido (Pull Payment)

```solidity
mapping(address => uint256) public refunds;

function withdrawRefund() external {
    uint256 amount = refunds[msg.sender];
    require(amount > 0, "no refund");

    refunds[msg.sender] = 0;
    (bool ok, ) = payable(msg.sender).call{value: amount}("");
    require(ok, "refund failed");
}
```

### 📌 Explicação

Um único receiver que revertesse travava todos os refunds.
Pull payment elimina loops e bloqueios globais.

---

## 3️⃣ Correções Adicionais (Boas Práticas)

### ❌ Antes

```solidity
// sem validações
```

### ✅ Depois

```solidity
require(to != address(0), "to=0");
require(minter != address(0), "minter=0");
require(msg.value == mintPrice, "wrong price");
```

📌 Evita:

* Endereços inválidos
* Estado inconsistente
* ETH preso no contrato

---

## 4️⃣ Resumo Comparativo

| Item               | Vulnerável | Corrigido |
| ------------------ | ---------- | --------- |
| Initialize seguro  | ❌          | ✅         |
| `tx.origin`        | ❌          | ✅         |
| Controle de Mint   | ❌          | ✅         |
| Overwrite de token | ❌          | ✅         |
| DoS por refund     | ❌          | ✅         |
| Validações básicas | ❌          | ✅         |

---

## 5️⃣ Conclusão Final

A versão corrigida elimina **todas as 
---

