# 🏃‍♂️ **Construindo Web3 Segura: Front-Running e MEV em Smart Contracts**

> *"Front-running é como furar a fila do pão quente: o hacker pega o melhor pedaço, e você fica com migalhas!"*  
> — *Inspirado por Hacken: "Hackers evoluem, mas devs preparados vencem!"* 🛡️

Em 2025, a Web3 pulsa com **US$ 200 bilhões em TVL** (Total Value Locked) em DeFi, NFTs e dApps, rodando em blockchains como Ethereum e BNB Chain. Smart contracts são como **leilões digitais** onde todos veem as apostas, mas **front-running** e **MEV (Miner Extractable Value)** permitem que hackers e mineradores "furem a fila" para lucrar às custas dos outros. Classificados como **A08 no OWASP Smart Contract Top 10 2025**, esses ataques, incluindo **sandwich attacks**, representaram **10% dos hacks em 2024**, custando milhões em DEXs e jogos. Este artigo explora front-running e MEV com uma abordagem **didática e técnica**, analisando o **Fomo3D Hack (2018)** e o **Bancor Hack (2018)**, com práticas para proteger a Web3. Vamos fechar a fila? 💪

---

## 🚨 **O que são Front-Running e MEV?**

Imagine fazer um lance em um leilão online, mas alguém vê seu lance, paga uma "gorjeta" ao leiloeiro e coloca um lance maior na sua frente. Na blockchain, **front-running** ocorre quando atacantes monitoram o **mempool** (fila de transações pendentes) e inserem transações com mais gas para serem executadas antes, roubando lucros. **MEV (Miner Extractable Value)** é o lucro que mineradores ou validadores ganham ao **reordenar**, incluir ou excluir transações, como em **sandwich attacks**, onde uma transação do usuário é "sanduichada" entre duas do atacante para manipular preços. A **falta de proteção contra slippage** em DEXs amplifica o problema.

> 😄 *Piada*: "No mempool, quem paga mais gas vira VIP, e o hacker leva o bolo – literalmente!"

**Como funciona na prática?** Na Ethereum, transações aguardam no mempool até serem mineradas. Atacantes usam bots para:  
- **Front-Running**: Antecipar compras em DEXs, lances em leilões ou votos em DAOs.  
- **Sandwich Attacks**: Colocar uma compra antes (infla preço) e uma venda depois (lucra com slippage) de uma transação-alvo.  
- **MEV**: Mineradores reordenam transações para maximizar lucros (ex.: priorizando sandwich attacks).  

**Estatísticas de Impacto**: Front-running e MEV representaram **10% dos hacks em 2024**, com perdas significativas em DEXs e jogos. O **Fomo3D Hack (2018)** e casos como o **Bancor Hack** mostram como esses ataques abalam a confiança na Web3.

---

## 🛠 **Contexto Técnico: Como Front-Running e MEV Funcionam**

### **Mecânica do Ataque**

1. **Front-Running**  
   - **Erro**: Contratos expõem transações no mempool sem proteção contra reordenação.  
   - **Exploração**: Bots monitoram o mempool e enviam transações com gas mais alto para antecipar ações (ex.: compras, lances).  
   - **Exemplo**: Um usuário compra 1 ETH em uma DEX; o atacante vê, compra antes, eleva o preço e vende com lucro.

2. **Sandwich Attacks**  
   - **Erro**: DEXs sem limites de slippage permitem manipulação de preços.  
   - **Exploração**: Atacante insere compra antes (infla preço) e venda depois (lucra com slippage), "sanduichando" a transação do usuário.  
   - **Exemplo**: Usuário troca USDC por ETH; atacante infla preço ETH/USDC e lucra.

3. **MEV**  
   - **Erro**: Mineradores/validadores controlam a ordem das transações.  
   - **Exploração**: Priorizam transações lucrativas (ex.: sandwich attacks) para maximizar taxas de gas.  

**Passos de um Ataque Típico**:  
1. **Monitoramento**: Bots escaneiam o mempool por transações lucrativas (ex.: grandes compras).  
2. **Front-Running**: Atacante envia transação com gas mais alto para antecipar (ex.: compra antes de um leilão).  
3. **Sandwich Attack**: Insere compra antes e venda depois de uma transação-alvo.  
4. **MEV**: Mineradores reordenam transações para lucrar.  
5. **Impacto**: Usuários pagam preços inflados ou perdem lances.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LeilaoVulneravel {
    uint public lanceMaior;
    address public maiorLicitante;

    function darLance(uint valor) public {
        require(valor > lanceMaior, "Lance muito baixo");
        lanceMaior = valor; // Visível no mempool
        maiorLicitante = msg.sender;
    }

    function swap(uint valorEntrada, address tokenSaida) public {
        uint preco = getPrecoSpot(); // Sem proteção de slippage
        uint valorSaida = valorEntrada * preco;
        (bool sucesso, ) = tokenSaida.call{value: valorSaida}("");
        require(sucesso, "Falha");
    }

    function getPrecoSpot() public view returns (uint) {
        return 2000; // Preço vulnerável
    }
}
```

**Como o ataque funciona?**  
- **Front-Running**: Usuário envia `darLance(100)`; atacante vê no mempool, envia `darLance(101)` com mais gas, vencendo.  
- **Sandwich Attack**: Usuário chama `swap(1 ether, tokenUSDC)`; atacante compra ETH antes (infla preço de US$ 2.000 para US$ 2.500) e vende depois, lucrando com slippage.  
- **MEV**: Minerador prioriza transações do atacante para maximizar taxas.

**Contrato Atacante**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Atacante {
    LeilaoVulneravel public leilao;

    constructor(address _leilao) {
        leilao = LeilaoVulneravel(_leilao);
    }

    function frontRun(uint valorVisto) public {
        leilao.darLance(valorVisto + 1); // Antecipa lance
    }

    function sandwich(address tokenSaida, uint valorEntrada) public {
        leilao.swap(valorEntrada, tokenSaida); // Compra antes
        // Após swap do usuário, vende
        leilao.swap(valorEntrada, tokenSaida);
    }
}
```

**Por que é perigoso?** O mempool é público, e mineradores têm incentivos para reordenar transações. Sandwich attacks exploram slippage em DEXs, custando milhões.

---

## 📊 **Casos Reais: Fomo3D Hack (2018) e Bancor Hack (2018)**

### **Fomo3D Hack (2018)**  
- **Contexto**: Jogo de loteria na Ethereum onde jogadores compravam "chaves" para um prêmio crescente, vencendo com a última compra após um temporizador.  
- **Ataque**: Front-running manipulou o timing de vitória.  
- **Como funcionou?**:  
  - Atacante monitorou o mempool para compras de chaves próximas ao fim do temporizador.  
  - Enviou transação com gas mais alto para comprar a última chave, ganhando **milhões em ETH**.  
  - Mineradores priorizaram via MEV.  
- **Impacto**:  
  - Colapso do jogo, com perdas significativas.  
  - Abalou confiança em jogos na blockchain.  
- **Lição**:  
  - Use *commit-reveal schemes*.  
  - Adicione delays para lances.  
  - Audite lógica sensível ao timing.

### **Bancor Hack (2018)**  
- **Contexto**: Bancor, DEX na Ethereum, permitia trocas com preços baseados em pools.  
- **Ataque**: Sandwich attack explorou slippage em grandes transações.  
- **Como funcionou?**:  
  - Atacante identificou compra no mempool, inseriu compra antes (inflou preço) e venda depois (lucrou com slippage).  
  - Drenou **US$ 23,5 milhões**.  
- **Impacto**:  
  - Bancor pausou operações.  
  - Acelerou adoção de MEV relays.  
- **Lição**:  
  - Implemente limites de slippage.  
  - Use MEV relays (ex.: Flashbots).  
  - Teste contra sandwich attacks.

---

## 🛡️ **Prevenção Moderna contra Front-Running e MEV (2025)**

### **Boas Práticas Técnicas**
- **Commit-Reveal Schemes** 🔒  
  - Oculte intenções em duas fases: commit (envia hash) e reveal (revela valor).  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract LeilaoSeguro {
      mapping(address => bytes32) public commits;
      uint public lanceMaior;
      address public maiorLicitante;

      function commitLance(bytes32 hash) public {
          commits[msg.sender] = hash; // Oculta lance
      }

      function revealLance(uint valor, bytes32 segredo) public {
          require(keccak256(abi.encode(valor, segredo)) == commits[msg.sender], "Hash inválido");
          require(valor > lanceMaior, "Lance muito baixo");
          lanceMaior = valor;
          maiorLicitante = msg.sender;
      }
  }
  ```  
- **Proteção contra Slippage** 📉  
  - Adicione limites em DEXs (ex.: Uniswap V3).  
  ```solidity
  function swap(uint valorEntrada, uint minSaida) public {
      uint preco = getPrecoTWAP();
      uint valorSaida = valorEntrada * preco;
      require(valorSaida >= minSaida, "Slippage excessivo");
      (bool sucesso, ) = msg.sender.call{value: valorSaida}("");
      require(sucesso, "Falha");
  }
  ```  
- **MEV Relays**: Use Flashbots para reduzir manipulação.  
- **Delays/Randomização**: Adicione delays ou Chainlink VRF em leilões.  
- **Auditorias**: Halborn (92% de detecção).

### **Ferramentas de Prevenção**
- **Slither/Mythril**: Detectam lógica vulnerável (92% eficaz).  
- **Tenderly**: Monitora mempool.  
- **Fuzzing (Echidna)**: Simula front-running.  
- **Bounties**: Immunefi pagou **US$ 52K médio** por bugs em 2024.

### **Tendências em 2025**
Front-running e MEV (A08) causam **10% dos hacks**, com impacto em DEXs e jogos. MEV relays e *commit-reveal* reduzem perdas, mas sandwich attacks persistem.

---

## 🎯 **Conclusão: Parando os Fura-Filas da Blockchain**

Front-running e MEV, como no **Fomo3D Hack (2018)** e **Bancor Hack (2018)**, são como furar a fila em um leilão digital. Com **10% dos hacks** ligados a A08, a solução é clara: use **commit-reveal**, limite **slippage** e adote **MEV relays**. Ferramentas como Slither, Tenderly e auditorias são as muralhas contra esses ataques. Como disse a Hacken: *"Hackers evoluem, mas devs preparados vencem!"* Vamos fechar a fila? 💪

> ❓ *Pergunta Interativa*: "Se você fosse dev do Fomo3D, como teria evitado o front-running?"

---