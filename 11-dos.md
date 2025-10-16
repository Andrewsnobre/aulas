# 🛑 **Construindo Web3 Segura: Negação de Serviço (DoS) On-Chain em Smart Contracts**

> *"DoS on-chain é como entupir o caixa eletrônico com chiclete – ninguém mais saca, e o hacker dá risada!"*  
> — *Inspirado por Hacken: "Hackers evoluem, mas devs preparados vencem!"* 🛡️

Em **2025**, a Web3 é o motor da economia digital, com **mais de US$ 200 bilhões em TVL** em DeFi, NFTs e dApps, rodando em blockchains como **Ethereum** e **BNB Chain**. Smart contracts são **máquinas digitais** que devem operar sem pausas, mas um ataque de **Negação de Serviço (DoS) on-chain**, classificado como **A09 no OWASP Smart Contract Top 10 2025**, joga areia nas engrenagens, travando filas, forçando reverts ou bloqueando ações. Representando **5% dos hacks em 2024**, o DoS impacta jogos, leilões e DeFi, causando perdas de funcionalidade e confiança. Este artigo explora o DoS on-chain com uma abordagem **didática e técnica**, analisando o **King of the Hill Hack (2018)** e o **Poly Network Hack (2021)**, com práticas para manter o motor da Web3 funcionando. Vamos desentupir o sistema? 💪

---

## 🚨 **O que é DoS On-Chain?**

Imagine um banco com uma única fila onde um cliente malicioso bloqueia todos os outros, ou um caixa que trava ao tentar processar uma transação gigante. **DoS on-chain** ocorre quando atacantes exploram falhas na lógica de smart contracts para impedir ações de outros usuários, como saques, depósitos ou tarefas críticas. Isso é feito por:  
- **Travar Filas**: Monopolizar processos sequenciais (ex.: leilões).  
- **Forçar Reverts**: Criar condições que fazem transações falharem.  
- **Consumo de Gas**: Usar loops caros para esgotar limites de gas.  
- **Bloqueio de Ações**: Impedir saques ou interações via estados manipulados.

> 😄 *Piada*: "DoS na blockchain? É como trancar a porta do banco e jogar a chave fora!"

**Como funciona na prática?** Contratos em jogos, leilões ou DeFi podem ter vulnerabilidades que permitem:  
- **Dependências Externas**: Chamadas a contratos ou oráculos que falham, travando o sistema.  
- **Loops Caros**: Iterações que consomem gas excessivo, bloqueando funções.  
- **Estados Bloqueados**: Lógica que impede ações se condições específicas são atingidas.  

**Estatísticas de Impacto**: DoS on-chain (A09) causou **5% dos hacks em 2024**, com impacto em jogos e DeFi. O **King of the Hill Hack (2018)** paralisou um jogo, e o **Poly Network Hack (2021)** mostrou como o DoS amplifica outros ataques.

---

## 🛠 **Contexto Técnico: Como Funciona o DoS On-Chain**

### **Mecânica do Ataque**

1. **Travar Filas ou Estados**  
   - **Erro**: Contratos com lógica sequencial (ex.: leilões) que podem ser monopolizados.  
   - **Exploração**: Atacante envia transações que travam a fila ou mantêm estados bloqueados.  
   - **Exemplo**: Lance inválido em um leilão que impede novos lances.

2. **Forçar Reverts**  
   - **Erro**: Dependência de chamadas externas que podem falhar.  
   - **Exploração**: Atacante provoca falhas (ex.: contrato sem `receive`), travando funções.  
   - **Exemplo**: Reembolso que reverte, bloqueando o contrato.

3. **Consumo Excessivo de Gas**  
   - **Erro**: Loops sem limites de gas.  
   - **Exploração**: Atacante envia entradas que consomem gas, travando o contrato.  

4. **Bloqueio de Retiradas**  
   - **Erro**: Lógica que impede saques em certos estados.  
   - **Exploração**: Atacante manipula o estado para bloquear retiradas.

**Passos de um Ataque Típico**:  
1. **Análise**: Atacante examina código público por lógica vulnerável (ex.: loops, chamadas externas).  
2. **Exploração**: Envia transações que monopolizam filas, forçam reverts ou consomem gas.  
3. **Impacto**: Paralisação do contrato, perda de funcionalidade ou confiança.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LeilaoVulneravel {
    address public maiorLicitante;
    uint public lanceMaior;

    function darLance() public payable {
        require(msg.value > lanceMaior, "Lance muito baixo");
        (bool sucesso, ) = maiorLicitante.call{value: lanceMaior}(""); // Vulnerável
        require(sucesso, "Falha no reembolso");
        lanceMaior = msg.value;
        maiorLicitante = msg.sender;
    }

    function distribuirPremio(address[] memory usuarios) public {
        // Vulnerável: Loop caro
        for (uint i = 0; i < usuarios.length; i++) {
            (bool sucesso, ) = usuarios[i].call{value: 1 ether}("");
            require(sucesso, "Falha");
        }
    }
}
```

**Como o ataque funciona?**  
- **Travar Fila**: Atacante envia lance com `maiorLicitante` que reverte (ex.: contrato sem `receive`), travando `darLance`.  
- **Consumo de Gas**: Chama `distribuirPremio` com lista gigante de `usuarios`, esgotando gas.  
- **Bloqueio**: Reembolso em `darLance` falha, impedindo novos lances.

**Contrato Atacante**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Atacante {
    LeilaoVulneravel public leilao;

    constructor(address _leilao) {
        leilao = LeilaoVulneravel(_leilao);
    }

    function atacar() public payable {
        leilao.darLance{value: 1 ether}(); // Trava reembolso
        address[] memory usuarios = new address[](10000); // Lista grande
        leilao.distribuirPremio(usuarios); // Consome gas
    }

    receive() external payable {
        revert("Bloqueado"); // Impede reembolso
    }
}
```

**Por que é perigoso?** A transparência da blockchain expõe lógica vulnerável, e chamadas externas ou loops caros facilitam o DoS. Parte dos **5% dos hacks em 2024** (A09).

---

## 📊 **Casos Reais: King of the Hill Hack (2018) e Poly Network Hack (2021)**

### **King of the Hill Hack (2018)**  
- **Contexto**: Jogo na Ethereum onde jogadores competiam pelo "trono" com lances, reembolsando o anterior.  
- **Ataque**: Contrato malicioso travou reembolsos, paralisando o jogo.  
- **Como funcionou?**:  
  - Atacante enviou lance com contrato que revertia ao receber ETH.  
  - Isso travou o reembolso, impedindo novos lances e mantendo o atacante no "trono".  
  - Drenou **milhares de ETH** em prêmios.  
- **Impacto**:  
  - Jogo paralisado, confiança abalada.  
  - Expôs riscos de chamadas externas.  
- **Lição**:  
  - Use *pull-over-push* para retiradas.  
  - Evite dependências externas.

### **Poly Network Hack (2021)**  
- **Contexto**: Ponte cross-chain gerenciando bilhões em ativos.  
- **Ataque**: DoS amplificou um hack de **US$ 611M** ao travar funções administrativas.  
- **Como funcionou?**:  
  - Vulnerabilidade permitiu chamadas externas que revertem, bloqueando respostas do protocolo.  
  - Facilitou dreno de fundos por controle de acesso.  
- **Impacto**:  
  - Maior hack de 2021, fundos devolvidos após negociação.  
  - Reforçou riscos de DoS em pontes.  
- **Lição**:  
  - Limite chamadas externas.  
  - Use timelocks para ações críticas.

---

## 🛡️ **Prevenção Moderna contra DoS On-Chain (2025)**

### **Boas Práticas Técnicas**  
- **Pull-over-Push** 🔒  
  - Substitua transferências automáticas por retiradas manuais.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract LeilaoSeguro {
      mapping(address => uint) public pendenteRetirada;
      uint public lanceMaior;
      address public maiorLicitante;

      function darLance() public payable {
          require(msg.value > lanceMaior, "Lance muito baixo");
          pendenteRetirada[maiorLicitante] += lanceMaior;
          lanceMaior = msg.value;
          maiorLicitante = msg.sender;
      }

      function retirar() public {
          uint valor = pendenteRetirada[msg.sender];
          pendenteRetirada[msg.sender] = 0;
          (bool sucesso, ) = msg.sender.call{value: valor}("");
          require(sucesso, "Falha");
      }
  }
  ```  
- **Limites de Gas** ⏳  
  - Restrinja loops com contadores.  
  ```solidity
  function distribuirPremio(address[] memory usuarios, uint limite) public {
      require(limite <= 100, "Limite excedido");
      for (uint i = 0; i < limite && i < usuarios.length; i++) {
          (bool sucesso, ) = usuarios[i].call{value: 1 ether}("");
          require(sucesso, "Falha");
      }
  }
  ```  
- **Evitar Dependências Externas**: Minimize chamadas a contratos ou oráculos.  
- **Auditorias**: Contrate Halborn (92% de detecção).  
- **Testes**: Simule DoS com Echidna.

### **Ferramentas de Prevenção**  
- **Slither/Mythril**: Detectam loops caros (92% eficaz).  
- **Tenderly**: Monitora consumo de gas.  
- **Fuzzing (Echidna)**: Testa DoS.  
- **Bounties**: Immunefi pagou **US$ 52K médio** por bugs em 2024.

### **Tendências em 2025**  
DoS on-chain (A09) causou **5% dos hacks**, impactando jogos e DeFi. Padrões como *pull-over-push* e limites de gas reduzem riscos, mas legados são vulneráveis.

---

## 🎯 **Conclusão: Mantendo o Motor Ligado**

DoS on-chain, como no **King of the Hill Hack (2018)** e **Poly Network Hack (2021)**, trava o motor da Web3. Com **5% dos hacks** ligados a A09, a solução é clara: use **pull-over-push**, limite gas e evite dependências externas. Ferramentas como Slither, Echidna e Tenderly são as muralhas contra esses ataques. Como disse a Hacken: *"Hackers evoluem, mas devs preparados vencem!"* Vamos manter o motor ligado? 💪

> ❓ *Pergunta Interativa*: "Se você fosse dev do King of the Hill, como teria evitado o DoS?"

---
