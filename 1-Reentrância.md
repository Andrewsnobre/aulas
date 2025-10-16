# 🔄 **Construindo Web3 Segura: O Ataque de Reentrância em Smart Contracts**

> *"Reentrância é o pesadelo do dev: empresta o dinheiro e, antes de anotar, o ‘amigo’ pede de novo… e de novo!"*  
> — *Inspirado por Hacken: "Hackers evoluem, mas devs preparados vencem!"* 🛡️

Em **2025**, smart contracts são o coração da **Web3**, gerenciando **mais de US$ 200 bilhões em TVL** em DeFi, NFTs e dApps, rodando em blockchains como **Ethereum** e **BNB Chain**. São **cofres de vidro**: transparentes, imutáveis, mas frágeis se mal projetados. **Reentrância (A04)** no **OWASP Smart Contract Top 10 2025** ocorre quando um contrato faz chamadas externas antes de atualizar o estado, permitindo que atacantes re-entrem na função e drenem fundos. Em **2024**, causou **~US$ 35 milhões em perdas**. Este artigo explora reentrância com uma abordagem **didática e técnica**, analisando o **The DAO Hack (2016)**, um marco que mudou a Ethereum, com práticas para proteger a Web3. Vamos fechar esse cofre? 💪

---

## 🚨 **O que é Reentrância?**

Pense num caixa eletrônico que entrega R$ 100 **antes** de descontar seu saldo. Se você sacar novamente nesse intervalo, ele paga de novo, porque o saldo não foi atualizado. **Reentrância** acontece quando um smart contract faz uma **chamada externa** (ex.: envia ETH) antes de atualizar variáveis críticas (ex.: `saldos[msg.sender] = 0`). Um contrato malicioso intercepta a chamada via `receive`/`fallback` e re-entra na função, repetindo a ação até drenar os fundos.

> 😄 *Piada*: "Reentrância? É como um banco que te dá o dinheiro e esquece de debitar!"

**Como funciona na prática?**  
- Contrato envia ETH/tokens antes de zerar o saldo.  
- Atacante re-entra via `receive`/`fallback`, chamando a mesma função.  
- O saldo, ainda não atualizado, permite múltiplos saques.  

**Estatísticas de Impacto**: Reentrância (A04) causou **US$ 35M em perdas em 2024**, com contratos legados e fluxos complexos como alvos. O **The DAO Hack (2016)** drenou **US$ 50M**, moldando práticas modernas.

---

## 🛠 **Contexto Técnico: Como Funciona a Reentrância**

### **Mecânica do Ataque**

1. **Chamada Externa Prematura**:  
   - **Erro**: Enviar ETH/tokens (ex.: via `call`) antes de atualizar o estado.  
   - **Exploração**: Atacante re-entra na função via `receive`/`fallback`.  
   - **Exemplo**: Saque que paga antes de zerar `saldos`.

2. **Ciclo de Reentrância**:  
   - **Erro**: Falta de guarda (ex.: `ReentrancyGuard`) ou padrão CEI (Checks-Effects-Interactions).  
   - **Exploração**: Atacante repete chamadas até esgotar fundos ou gas.  

3. **Dependência de Contratos Externos**:  
   - **Erro**: Interagir com contratos não confiáveis.  
   - **Exploração**: Contrato malicioso explora a janela de reentrância.

**Passos de um Ataque Típico**:  
1. **Análise**: Atacante examina código público por chamadas externas antes de atualizações.  
2. **Exploração**: Implanta contrato que re-entra na função vulnerável.  
3. **Impacto**: Drena fundos ou corrompe o contrato.

### **Exemplo de Código Solidity Vulnerável**

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
        // Vulnerável: Chamada externa antes de atualizar estado
        (bool ok, ) = msg.sender.call{value: valor}("");
        require(ok, "Falha no envio");
        saldos[msg.sender] = 0; // Tarde demais
    }
}
```

**Contrato Atacante**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Atacante {
    BancoVulneravel public banco;

    constructor(address _banco) {
        banco = BancoVulneravel(_banco);
    }

    function atacar() external payable {
        require(msg.value >= 1 ether, "Precisa de 1 ETH");
        banco.depositar{value: 1 ether}();
        banco.sacar();
    }

    receive() external payable {
        if (address(banco).balance >= 1 ether) {
            banco.sacar(); // Re-entra antes de zerar saldo
        }
    }
}
```

**Como o ataque funciona?**  
- Atacante deposita 1 ETH e chama `sacar`.  
- `sacar` envia 1 ETH, acionando `receive` do atacante.  
- `receive` chama `sacar` novamente, antes de `saldos[msg.sender] = 0`.  
- Repete até drenar o contrato.

**Contrato Seguro**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BancoSeguro is ReentrancyGuard {
    mapping(address => uint256) public saldos;

    function depositar() external payable {
        saldos[msg.sender] += msg.value;
    }

    function sacar() external nonReentrant {
        uint256 valor = saldos[msg.sender];
        require(valor > 0, "Sem saldo");
        saldos[msg.sender] = 0; // Efeito primeiro
        (bool ok, ) = msg.sender.call{value: valor}("");
        require(ok, "Falha no envio");
    }
}
```

**Por que é perigoso?** A transparência da blockchain expõe chamadas externas, e a ausência de CEI ou guardas permite drenagem rápida. Em 2024, **US$ 35M** foram perdidos para A04.

---

## 📊 **Caso Real: The DAO Hack (2016)**

### **Contexto**  
- **The DAO**: Fundo descentralizado na Ethereum para propostas e votação, arrecadando **US$ 150M (~3,6M ETH)**, ou **14% do ETH circulante**.  
- Solidity imaturo, sem padrões consolidados.

### **Ataque**  
- **Vulnerabilidade**: Função `splitDAO` enviava ETH antes de zerar `credit`, permitindo reentrância.  
- **Como funcionou?**:  
  - Atacante chamou `splitDAO`, que enviou ETH ao seu contrato.  
  - No `fallback`, re-entrou em `splitDAO`, repetindo antes de `credit = 0`.  
  - Drenou **~3,6M ETH (US$ 50M)**.  

### **Impacto**  
- **Financeiro**: Perda massiva, congelamento de fundos.  
- **Comunitário**: Hard fork criou **Ethereum** (revertida) e **Ethereum Classic** (original).  
- **Técnico**: Adoção de CEI, `ReentrancyGuard` e auditorias.

### **Lições**  
- Atualize estados antes de chamadas externas.  
- Use guardas de reentrância.  
- Teste com fuzzing e auditorias.

---


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



---




## 🛡️ **Prevenção Moderna contra Reentrância (2025)**

### **Boas Práticas Técnicas**  
- **Checks-Effects-Interactions (CEI)** 🔒  
  - Atualize estados antes de chamadas externas.  
  ```solidity
  function sacar() external nonReentrant {
      uint256 valor = saldos[msg.sender];
      require(valor > 0, "Sem saldo");
      saldos[msg.sender] = 0; // Efeito
      (bool ok, ) = msg.sender.call{value: valor}(""); // Interação
      require(ok, "Falha");
  }
  ```  
- **ReentrancyGuard** ⏳  
  - Use OpenZeppelin para bloquear reentrância.  
  ```solidity
  import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
  contract BancoSeguro is ReentrancyGuard {
      // Funções protegidas com nonReentrant
  }
  ```  
- **Pull-over-Push**: Substitua pagamentos automáticos por retiradas manuais.  
  ```solidity
  function retirar() public nonReentrant {
      uint256 valor = pendenteRetirada[msg.sender];
      pendenteRetirada[msg.sender] = 0;
      (bool ok, ) = msg.sender.call{value: valor}("");
      require(ok, "Falha");
  }
  ```  
- **Minimizar Chamadas Externas**: Evite interações com contratos não confiáveis.  
- **Auditorias**: Contrate Halborn (92% de detecção).

### **Ferramentas de Prevenção**  
- **Slither/Mythril**: Detectam padrões de reentrância (92% eficaz).  
- **Echidna/Foundry**: Fuzzing para simular reentrância.  
- **Tenderly**: Monitora chamadas suspeitas.  
- **Bounties**: Immunefi pagou **US$ 52K médio** por bugs em 2024.

### **Tendências em 2025**  
Reentrância (A04) causou **US$ 35M em perdas** em 2024, com contratos legados como alvos. CEI e `ReentrancyGuard` reduziram a incidência, mas fluxos complexos ainda são vulneráveis.

---

## 🎯 **Conclusão: Fechando o Cofre de Vidro**

Reentrância, como no **The DAO Hack (2016)**, transforma cofres digitais em vidro frágil. Com **US$ 35M perdidos em 2024**, a solução é clara: **CEI**, **ReentrancyGuard**, **pull-over-push** e auditorias robustas. Ferramentas como Slither, Echidna e Tenderly são as muralhas contra esses ataques. Como disse a Hacken: *"Hackers evoluem, mas devs preparados vencem!"* Vamos trancar esse cofre? 💪

> ❓ *Pergunta Interativa*: "Se você estivesse no time do The DAO, quais 3 mudanças teria implementado para impedir o ataque?"

---