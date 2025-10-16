

# **Artigo: O Ataque de Reentrância em Smart Contracts**

### **Um mergulho profundo no The DAO Hack**

> **Em uma frase:** reentrância é quando o contrato paga antes de dar baixa — e o atacante “volta” para receber de novo.

---

## **Introdução — O Cofre de Vidro da Web3**

Em **2025**, *smart contracts* são o coração da **Web3**: gerenciam bilhões em **DeFi, NFTs e dApps** em redes como **Ethereum** e **Solana**. São **transparentes e imutáveis**, mas podem se tornar **cofres de vidro**: se o design estiver errado, quebram fácil. Entre as falhas mais emblemáticas está a **reentrância (reentrancy)** — quando um contrato faz **chamadas externas antes de atualizar o próprio estado**, permitindo que um atacante **re-entre** na função e repita uma retirada várias vezes.
Segundo o **OWASP Smart Contract Top 10 2025**, reentrância (A04) segue relevante: em **2024**, estimam-se **~US$ 35 milhões** em perdas atribuídas a essa classe (*estimativas citadas*). Historicamente, o **The DAO Hack (2016)** cristalizou o problema e **mudou o rumo da Ethereum**.

> 😄 **Para engajar:** *Reentrância é o pesadelo do dev: empresta o dinheiro e, antes de anotar, o “amigo” pede de novo… e de novo.*

---

## **O que é Reentrância? (explicação didática)**

Pense num **caixa eletrônico** que te entrega R$ 100 **antes** de descontar do saldo. Se você **aperta sacar novamente** nesse intervalo, recebe **mais R$ 100** porque o sistema **ainda pensa** que seu saldo continua lá.
Em *smart contracts*, isso acontece quando uma função **envia ETH/tokens (chamada externa)** e **só depois** atualiza variáveis críticas (ex.: `saldos[msg.sender] = 0`). Um contrato malicioso intercepta a chamada (via `receive`/`fallback`) e **chama de novo a mesma função** antes da atualização — **“re-entrando”** no fluxo — até drenar os fundos.

**Por que ainda acontece?**

* Contratos **legados** (pré-boas práticas).
* Fluxos complexos com **múltiplas interações externas**.
* Falta de **padrões** (Checks-Effects-Interactions) e de **guardas** (ReentrancyGuard).

---

## **Como a Reentrância funciona (visão técnica)**

1. **Contrato vulnerável** executa uma função de saque que **envia ETH** com `call` **antes** de zerar o saldo.
2. **Contrato atacante** recebe o ETH; no `receive()` ou `fallback()`, **chama novamente** a função de saque.
3. Como o estado **não foi atualizado**, a segunda chamada **ainda encontra saldo** e paga de novo.
4. O ciclo **se repete** até esgotar o balanço do contrato ou o **gas**.

---

## **Exemplo em Solidity — Vulnerável vs. Seguro**

### ❌ **Contrato vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BancoVulneravel {
    mapping(address => uint256) public saldos;

    function depositar() external payable {
        saldos[msg.sender] += msg.value;
    }

    function sacar() external {
        uint256 valor = saldos[msg.sender];
        require(valor > 0, "Sem saldo");

        // VULNERAVEL: Interacao externa ANTES dos efeitos
        (bool ok, ) = msg.sender.call{value: valor}("");
        require(ok, "Falha no envio");

        saldos[msg.sender] = 0; // Efeito tardio -> janela para reentrancia
    }
}
```

### ⚠️ **Contrato atacante (padrão didático)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBanco {
    function depositar() external payable;
    function sacar() external;
}

contract Atacante {
    IBanco public banco;

    constructor(address _banco) {
        banco = IBanco(_banco);
    }

    function atacar() external payable {
        require(msg.value >= 1 ether, "Precisa de 1 ETH");
        banco.depositar{value: 1 ether}();
        banco.sacar();
    }

    receive() external payable {
        if (address(banco).balance >= 1 ether) {
            banco.sacar(); // Re-entra enquanto o saldo nao foi zerado
        }
    }
}
```

### ✅ **Versão segura (Checks–Effects–Interactions + guarda)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancia");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract BancoSeguro is ReentrancyGuard {
    mapping(address => uint256) public saldos;

    function depositar() external payable {
        saldos[msg.sender] += msg.value;
    }

    function sacar() external nonReentrant {
        uint256 valor = saldos[msg.sender];
        require(valor > 0, "Sem saldo");

        // Effects (ANTES)
        saldos[msg.sender] = 0;

        // Interactions (DEPOIS)
        (bool ok, ) = msg.sender.call{value: valor}("");
        require(ok, "Falha no envio");
    }
}
```

> ✅ **Boas práticas:** **CEI** (Checks–Effects–Interactions), **ReentrancyGuard**, **mínimo de chamadas externas**, uso de **pull payments** (o usuário “puxa” o pagamento quando quiser, em vez de receber *push* automático).

---

## **The DAO Hack (2016) — a reentrância que abalou a Ethereum**

### **Contexto**

* **The DAO**: fundo de investimento **descentralizado**, com processos on-chain de **proposta e votação**.
* Arrecadou ~**US$ 150 milhões em ETH** (cerca de **3,6 milhões de ETH** na época) — **14%** do ETH circulante.
* Código em Solidity **ainda imaturo** (2016), sem padrões consolidados.

### **A vulnerabilidade**

A função de “*split*”/retirada **enviava ETH antes de atualizar o saldo** do usuário, abrindo a janela para **reentrância**.

**Esboço vulnerável (simplificado):**

```solidity
pragma solidity ^0.4.0;

contract TheDAO {
    mapping(address => uint256) public credit;

    function splitDAO(address receptor) public {
        uint256 valor = credit[msg.sender];
        if (valor > 0) {
            // Interacao externa primeiro -> vulneravel
            if (!receptor.call.value(valor)()) { revert(); }
            credit[msg.sender] = 0; // Efeito apos a interacao
        }
    }
}
```

**Contrato atacante (padrão da época, pseudo-legacy):**

```solidity
pragma solidity ^0.4.0;

contract Atacante {
    TheDAO public dao;

    function atacar(address _dao) public {
        dao = TheDAO(_dao);
        dao.splitDAO(this);
    }

    function() public payable {
        if (address(dao).balance >= 1 ether) {
            dao.splitDAO(this); // Re-entra enquanto credit nao foi zerado
        }
    }
}
```

### **Linha do tempo do ataque**

1. **Depósito**: o atacante participa do DAO e adquire “créditos”.
2. **Primeira chamada**: aciona a função de *split*, que **envia ETH** ao atacante.
3. **Reentrada**: no `fallback`, a mesma função é chamada **de novo**, **antes** do `credit[msg.sender] = 0`.
4. **Loop**: repete até **drenar ~3,6M ETH** (~**US$ 50M** na época).

### **Impacto e repercussões**

* **Financeiro**: drenagem massiva e congelamento temporário de fundos.
* **Comunitário**: debate sobre **imutabilidade** vs. **justiça** → **hard fork** que reverteu o hack na cadeia **Ethereum**; a cadeia **Ethereum Classic (ETC)** manteve o histórico original.
* **Técnico**: consolidação de padrões (**CEI**, **ReentrancyGuard**), foco em **auditorias** e **testes de segurança**.

### **Lições práticas (aplicáveis hoje)**

1. **Atualize estado antes de interações externas** (CEI).
2. **Use guardas de reentrância** (OpenZeppelin).
3. **Evite “pagar no meio do fluxo”** — prefira *pull payments*.
4. **Teste adversarialmente**: simule reentrância com **Echidna/Foundry**.
5. **Auditoria independente** quando o contrato **custodia valores relevantes**.

---

## **Prevenção moderna (2025) — do código ao processo**

### **Técnicas**

* **Solidity ≥ 0.8** (under/overflow com *revert*; reentrância ainda exige padrão).
* **CEI + ReentrancyGuard** como padrão de projeto.
* **Design sem chamadas externas** quando possível (minimize superfícies).
* **Limites**: *rate-limits*, *caps* por transação, *circuit breakers*.

### **Ferramentas**

* **Slither/Mythril**: estática para detectar padrões de reentrância.
* **Echidna/Foundry**: *fuzzing* e *property-based testing*.
* **Tenderly**: simulação e *monitoring* de execuções.
* **Bug bounties** (Immunefi): incentivo a *white hats*.

### **Processo**

* **Revisões cruzadas** (dupla de revisores).
* **Auditorias recorrentes** (2+ quando impacto é sistêmico).
* **Playbooks de resposta** (pausa, *kill switch*, comunicação).

---

## **Conclusão — do caos do The DAO à engenharia segura**

O **The DAO Hack** mostrou que **transparência** e **imutabilidade** são poderosas — e perigosas sem disciplina de engenharia.
A partir dele, a comunidade consolidou **boas práticas** (CEI, *guards*, auditoria, testes adversariais). Em **2025**, reentrância é **menos prevalente**, mas **não desapareceu**: contratos legados e fluxos mal desenhados ainda abrem portas.

> ❓ **Para a turma:** *Se você estivesse no time do The DAO, quais 3 mudanças teria implementado para impedir o ataque?*

