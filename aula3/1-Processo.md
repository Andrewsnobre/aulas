# Exemplo Completo de Auditoria de um Contrato Simples

Olá! Após explorarmos o processo de auditoria de contratos inteligentes em detalhes, vamos agora aplicar esse conhecimento em um **exemplo completo e prático** de uma auditoria de um contrato simples. Este guia simula o workflow de uma auditoria, usando um contrato básico escrito em Solidity, ferramentas como Slither, Echidna e Foundry, e revisões manuais. O objetivo é demonstrar como identificar, corrigir e validar vulnerabilidades em um ambiente realista, ideal para seus alunos aprenderem na prática. Vamos ao exemplo!

---

## Contexto do Exemplo

### Contrato a Auditar: `SimpleSavings`
Nosso contrato, `SimpleSavings`, é uma carteira de poupança básica que permite aos usuários depositar e sacar Ether, com um limite de saque diário. O cliente (um desenvolvedor) solicita uma auditoria antes do deployment na rede Ethereum mainnet, com base em Solidity 0.8.24. O contrato será auditado por uma equipe hipotética chamada "SecureChain Audits".

### Objetivo da Auditoria
- Garantir que depósitos e saques funcionem corretamente.
- Verificar a segurança contra reentrancy, overflows e manipulação de estado.
- Validar o limite diário de saque (100 Ether por dia por usuário).

### Ferramentas Utilizadas
- **Slither**: Análise estática.
- **Echidna**: Fuzzing de propriedades.
- **Foundry**: Testes unitários e deployment local.
- **Anvil**: Nó local para simulação.

---

## Etapa 1: Pré-Análise e Coleta de Informações

### Atividades
- **Reunião com o Cliente**: O cliente fornece documentação indicando que `SimpleSavings` deve limitar saques a 100 Ether/dia por endereço e garantir que saldos não fiquem negativos.
- **Código Recebido**: O repositório contém `SimpleSavings.sol` e testes básicos em `test/SimpleSavings.t.sol`.
- **Escopo Definido**: Auditoria focada em `SimpleSavings.sol`, Solidity 0.8.24, teste em Anvil e deployment simulado.

### Código Inicial
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SimpleSavings {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lastWithdrawTime;
    mapping(address => uint256) public dailyWithdrawLimit;

    uint256 public constant DAILY_LIMIT = 100 ether;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(amount <= DAILY_LIMIT - dailyWithdrawLimit[msg.sender], "Daily limit exceeded");
        require(block.timestamp >= lastWithdrawTime[msg.sender] + 1 days, "Wait 24h");

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] -= amount;
        dailyWithdrawLimit[msg.sender] += amount;
        lastWithdrawTime[msg.sender] = block.timestamp;

        emit Withdrawal(msg.sender, amount);
    }

    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
}
```

### Entregável
- Relatório inicial com escopo: "Auditar `SimpleSavings` por reentrancy, limites diários e lógica de estado."

---

## Etapa 2: Análise Estática do Código

### Atividades
- **Execução do Slither**:
  ```
  slither SimpleSavings.sol
  ```
- **Resultados**:
  ```
  INFO:Slither:Detector: reentrancy-no-eth
   |                        |   Location
  ------------------------|----------------------
   26  | (103) |  ❌  |  External call before state update in SimpleSavings.withdraw()

  INFO:Slither:Detector: timestamp
   |                        |   Location
  ------------------------|----------------------
   29  | (120) |  ⚠️   |  Dependency on block.timestamp in SimpleSavings.withdraw()

  Slither analyzed 1 contract with 0.15 seconds
  ```
  - **Reentrancy**: A chamada `msg.sender.call` ocorre antes de atualizar `balances`, permitindo ataques reentrantes.
  - **Timestamp**: `block.timestamp` pode ser manipulado por mineradores, afetando o limite diário.

- **Revisão Manual**:
  - Lógica de `dailyWithdrawLimit` é correta, mas reinicia apenas após 24h, o que é seguro.
  - Falta proteção contra reentrancy e validação de `amount > 0`.

### Entregável
- Relatório preliminar: "Detectada vulnerabilidade de reentrancy e risco em `block.timestamp`. Recomenda-se `nonReentrant` e validação de `amount`."

---

## Etapa 3: Testes Dinâmicos e Simulações

### Configuração do Ambiente
- Inicie Anvil:
  ```
  anvil
  ```
- Compile e teste com Foundry:
  ```
  forge build
  forge test
  ```

### Testes Unitários (Foundry)
Crie `test/SimpleSavings.t.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../SimpleSavings.sol";

contract SimpleSavingsTest is Test {
    SimpleSavings savings;
    address user = address(0x1);

    function setUp() public {
        savings = new SimpleSavings();
        vm.deal(user, 200 ether);
    }

    function testDeposit() public {
        vm.prank(user);
        savings.deposit{value: 100 ether}();
        assertEq(savings.getBalance(), 100 ether);
    }

    function testFuzzWithdraw(uint256 amount) public {
        vm.prank(user);
        savings.deposit{value: 200 ether}();
        vm.warp(block.timestamp + 1 days); // Pula 24h
        savings.withdraw(amount);
        assertLe(savings.dailyWithdrawLimit(user), 100 ether); // Limite diário
    }
}
```
- Resultado: `testFuzzWithdraw` falha com `amount > 100 ether` após um dia, confirmando limite diário, mas não testa reentrancy.

### Fuzzing com Echidna
Adicione propriedades em `TestSimpleSavings.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SimpleSavings.sol";

contract TestSimpleSavings is SimpleSavings {
    function echidna_balance_non_negative() public view returns (bool) {
        return balances[msg.sender] >= 0;
    }

    function echidna_daily_limit_respected() public view returns (bool) {
        return dailyWithdrawLimit[msg.sender] <= DAILY_LIMIT;
    }
}
```
Rode:
```
echidna TestSimpleSavings.sol --contract TestSimpleSavings
```
- Resultado: `echidna_balance_non_negative` falha com reentrancy (sequência: `withdraw` reentrante drena saldo).

### Simulação de Ataque
Crie um contrato malicioso `ReentrancyAttacker.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ReentrancyAttacker {
    SimpleSavings public target;

    constructor(address _target) {
        target = SimpleSavings(_target);
    }

    receive() external payable {
        if (address(target).balance >= 1 ether) {
            target.withdraw(1 ether);
        }
    }

    function attack() public payable {
        target.withdraw(1 ether);
    }
}
```
- Deploy em Anvil, chame `attack` e observe o saldo drenar.

### Entregável
- Relatório de testes: "Reentrancy confirmada; limite diário funciona, mas timestamp é vulnerável."

---

## Etapa 4: Correção e Validação

### Correções Propostas
O cliente atualiza `SimpleSavings.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleSavings is ReentrancyGuard {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lastWithdrawTime;
    mapping(address => uint256) public dailyWithdrawLimit;

    uint256 public constant DAILY_LIMIT = 100 ether;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Amount must be positive");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(amount <= DAILY_LIMIT - dailyWithdrawLimit[msg.sender], "Daily limit exceeded");
        require(block.timestamp >= lastWithdrawTime[msg.sender] + 1 days || dailyWithdrawLimit[msg.sender] == 0, "Wait 24h");

        balances[msg.sender] -= amount;  // Atualiza estado primeiro
        dailyWithdrawLimit[msg.sender] += amount;
        lastWithdrawTime[msg.sender] = block.timestamp;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit Withdrawal(msg.sender, amount);
    }

    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
}
```
- Adiciona `nonReentrant`, valida `amount > 0`, e ajusta a lógica de `lastWithdrawTime`.

### Validação
- **Slither**: `slither SimpleSavings.sol` – Nenhum alerta de reentrancy.
- **Echidna**: `echidna TestSimpleSavings.sol` – Propriedades passam.
- **Foundry**: `forge test` – Todos os testes passam.

### Entregável
- Relatório de validação: "Vulnerabilidades corrigidas; contrato seguro."

---

## Etapa 5: Relatório Final e Recomendações

### Relatório Final
- **Resumo Executivo**: "Auditoria de `SimpleSavings` concluiu com sucesso. Risco inicial alto (reentrancy) mitigado."
- **Vulnerabilidades**:
  - Reentrancy: Corrigido com `nonReentrant`.
  - Timestamp: Risco baixo; sugerido uso de oráculos para precisão.
- **Métricas**: 100% de cobertura de testes, 0 vulnerabilidades críticas restantes.
- **Recomendações**:
  - Adicionar pausa (pause) com OpenZeppelin.
  - Monitorar em produção com Tenderly.

### Apresentação
Reunião com o cliente às 09:03 AM -03 de 23/10/2025, discutindo resultados e próxima reauditoria após updates.

### Entregável
- Relatório em PDF, com código corrigido anexado.

---

## Conclusão

Este exemplo demonstra um processo de auditoria completo para `SimpleSavings`, desde a identificação de reentrancy até a validação pós-correção. Ferramentas como Slither, Echidna e Foundry, combinadas com análise manual, garantem um contrato seguro. Para seus alunos, enfatize a importância de testar edge cases e iterar com o cliente. Que tal simular isso com um contrato próprio? Dúvidas? Comente! Happy auditing! 🔐
