# 🔢 **Construindo Web3 Segura: Overflow/Underflow e Erros Aritméticos em Smart Contracts**

> *"Quando a matemática falha na blockchain, o cofre vira peneira!"*  
> — *Inspirado por Hacken: "Hackers evoluem, mas devs preparados vencem!"* 🛡️

Em **2025**, a Web3 é o alicerce da economia digital, gerenciando **mais de US$ 200 bilhões em TVL** em DeFi, NFTs e dApps, rodando em blockchains como **Ethereum** e **BNB Chain**. Smart contracts são **calculadoras de alta precisão**, mas um erro matemático transforma o cofre em uma peneira. **Overflow/underflow** e **erros aritméticos**, associados a **validação insuficiente (A02)** no **OWASP Smart Contract Top 10 2025**, causaram **20% dos hacks em 2024**, com **US$ 223 milhões em perdas**. Apesar do **Solidity 0.8+** mitigar overflow/underflow, **erros de arredondamento** e **contabilidade imprecisa** seguem como alvos. Este artigo explora essas vulnerabilidades com uma abordagem **didática e técnica**, analisando o **BeautyChain (BEC) Hack (2018)** e o **BonqDAO Hack (2023)**, com práticas para blindar a Web3. Vamos consertar o odômetro digital? 💪

---

## 🚨 **O que são Overflow/Underflow e Erros Aritméticos?**

Imagine um odômetro de carro que, ao chegar a 999.999 km, volta a **0** – ou, pior, ao tentar retroceder de 0, pula para **999.999**. Na blockchain, **overflow/underflow** ocorre quando operações ultrapassam os limites de um tipo numérico (ex.: `uint8` de 0 a 255). **Erros de arredondamento** surgem em divisões ou cálculos que perdem precisão, criando **resíduos exploráveis** em shares, juros ou taxas.

> 😄 *Piada*: "Overflow é como ganhar um carro novo toda vez que o odômetro estoura – e hackers adoram essa concessionária on-chain!"

**Como funciona na prática?**  
- **Overflow**: `200 + 100` em `uint8` resulta em `44` (300 - 256).  
- **Underflow**: `0 - 1` em `uint8` vira `255`.  
- **Arredondamento**: Dividir 1 token entre 3 usuários pode gerar resíduos (ex.: `1 / 3 = 0` em inteiros), acumuláveis por atacantes.  

**Estatísticas de Impacto**: Em 2024, **20% dos hacks** (A02) envolveram erros aritméticos, com **US$ 223M perdidos**. O **BeautyChain Hack (2018)** e o **BonqDAO Hack (2023)** destacam o risco persistente.

---

## 🛠 **Contexto Técnico: Como o Ataque Acontece**

### **Mecânica do Ataque**

1. **Overflow/Underflow (Pré-Solidity 0.8)**  
   - **Erro**: Operações `+`, `-`, `*` sem verificações de limites.  
   - **Exploração**: Forçar transbordo (ex.: somar a `uint` próximo do limite) ou subtrair de zero, criando saldos absurdos.  
   - **Exemplo**: Subtrair `100` de um saldo `50` em `uint8` gera `206` (underflow).

2. **Erros de Arredondamento**  
   - **Erro**: Divisões inteiras ou cálculos sem escala decimal perdem precisão.  
   - **Exploração**: Atacantes repetem operações para acumular resíduos ou manipulam preços via oráculos frágeis.  
   - **Exemplo**: Divisão `1 / 3 = 0` em inteiros deixa resíduos exploráveis.

**Passos de um Ataque Típico**:  
1. **Análise**: Atacante examina o código público por operações aritméticas frágeis.  
2. **Exploração**: Envia entradas que causam overflow/underflow ou acumulam resíduos (ex.: via flash loans).  
3. **Lucro**: Realiza saques indevidos ou swaps com valores manipulados.  
4. **Impacto**: Drena fundos ou corrompe a contabilidade do contrato.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0; // Pré-0.8, sem checagens nativas

contract TokenVulneravel {
    mapping(address => uint8) public saldos; // 0 a 255

    function transferir(address para, uint8 valor) external {
        require(saldos[msg.sender] >= valor, "Saldo insuficiente");
        saldos[msg.sender] -= valor; // Underflow se valor > saldo
        saldos[para] += valor; // Overflow se ultrapassa 255
    }

    function juros(uint valor, uint taxaBps) external pure returns (uint) {
        return (valor * taxaBps) / 10_000; // Perde frações
    }
}
```

**Como o ataque funciona?**  
- **Overflow**: Atacante chama `transferir(address, 200)` com `saldos[para] = 100`, causando overflow (`100 + 200 = 44`).  
- **Underflow**: Chama `transferir(address, 100)` com `saldos[msg.sender] = 50`, gerando `255` (underflow).  
- **Arredondamento**: Repete `juros(1, 100)` para acumular resíduos de frações perdidas.

**Contrato Atacante**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract Atacante {
    TokenVulneravel public token;

    constructor(address _token) {
        token = TokenVulneravel(_token);
    }

    function atacar() public {
        token.transferir(address(this), 200); // Provoca overflow/underflow
        for (uint i = 0; i < 1000; i++) {
            token.juros(1, 100); // Acumula resíduos
        }
    }
}
```

**Por que é perigoso?** O código público da blockchain facilita a identificação de falhas aritméticas. Flash loans amplificam ataques, e resíduos de arredondamento podem ser acumulados em larga escala.

---

## 📊 **Casos Reais: BeautyChain (BEC) Hack e BonqDAO Hack**

### **BeautyChain (BEC) Hack (2018)**  
- **Contexto**: Token ERC-20 na Ethereum, com função de *batchTransfer*.  
- **Ataque**: Um overflow na função *batchTransfer* permitiu mintar tokens indevidos.  
- **Como funcionou?**:  
  - Função calculava `total = value * count` sem verificação de limites.  
  - Atacante usou valores grandes (ex.: `value = 2^256 / count`) para causar overflow, gerando um `total` válido mas absurdo.  
  - Mintou **bilhões de BEC**, despejando-os em exchanges.  
- **Impacto**:  
  - Preço do BEC colapsou; trading suspenso.  
  - Perdas de **milhões** e efeito dominó em exchanges.  
- **Lição**:  
  - Sempre valide limites em operações de *batch* ou *mint*.  
  - Use **SafeMath** (pré-0.8) ou Solidity 0.8+.  
  - Verifique invariantes (ex.: soma de saldos = *supply*).

### **BonqDAO Hack (2023)**  
- **Contexto**: Protocolo DeFi na Polygon, com cálculo de *shares* baseado em oráculos.  
- **Ataque**: Erros de arredondamento e manipulação de oráculo permitiram minting indevido.  
- **Como funcionou?**:  
  - Divisão inteira em *shares* gerava resíduos exploráveis.  
  - Atacante manipulou preço via oráculo, mintando **US$ 63M** em *shares* extras.  
- **Impacto**:  
  - Perdas de **dezenas de milhões**.  
  - Protocolo pausado, confiança abalada.  
- **Lição**:  
  - Use **TWAP/mediana** em oráculos (ex.: Chainlink).  
  - Adote **mulDiv** para precisão.  
  - Teste invariantes com fuzzing.

---

## 🛡️ **Prevenção Moderna contra Overflow/Underflow e Erros Aritméticos (2025)**

### **Boas Práticas Técnicas**  
- **Solidity 0.8+** 🛠  
  - Checagens nativas contra overflow/underflow.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.24;

  contract TokenSeguro {
      mapping(address => uint256) public saldos;

      function transferir(address para, uint256 valor) external {
          require(para != address(0), "Destinatário inválido");
          require(saldos[msg.sender] >= valor, "Saldo insuficiente");
          saldos[msg.sender] -= valor; // Reverte em underflow
          saldos[para] += valor; // Reverte em overflow
      }
  }
  ```  
- **SafeMath (Pré-0.8)** 🔒  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.7.6;
  import "@openzeppelin/contracts/math/SafeMath.sol";

  contract TokenSeguroLegacy {
      using SafeMath for uint256;
      mapping(address => uint256) public saldos;

      function transferir(address para, uint256 valor) external {
          saldos[msg.sender] = saldos[msg.sender].sub(valor); // Reverte underflow
          saldos[para] = saldos[para].add(valor); // Reverte overflow
      }
  }
  ```  
- **Arredondamento Seguro** 📏  
  - Use **Math.mulDiv** (OpenZeppelin) com arredondamento explícito.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.24;
  import "@openzeppelin/contracts/utils/math/Math.sol";

  function calcJuros(uint256 principal, uint256 taxaBps) external pure returns (uint256) {
      return Math.mulDiv(principal, taxaBps, 10_000, Math.Rounding.Floor);
  }
  ```  
- **Invariantes**: Adicione *asserts* (ex.: `assert(totalSupply == sumBalances)`).  
- **Oráculos Robustos**: Use Chainlink com TWAP para preços confiáveis.

### **Ferramentas de Prevenção**  
- **Slither/Mythril**: Detectam erros aritméticos (92% eficaz).  
- **Fuzzing (Echidna)**: Simula cenários extremos.  
- **Tenderly**: Monitora deltas contábeis anômalos.  
- **Bounties**: Immunefi pagou **US$ 52K médio** por bugs em 2024.

### **Tendências em 2025**  
Overflow/underflow (A02) representaram **20% dos hacks** em 2024, com **US$ 223M perdidos**. Solidity 0.8+ e bibliotecas como OpenZeppelin reduzem riscos, mas erros de arredondamento persistem em DeFi. Auditorias com IA e fuzzing prometem cortar perdas em **20% até 2026**.

---

## 🎯 **Conclusão: Consertando o Odômetro Digital**

Overflow/underflow e erros aritméticos, como no **BeautyChain Hack (2018)** e **BonqDAO Hack (2023)**, transformam cofres em peneiras. Com **20% dos hacks** ligados a A02, a solução é clara: use **Solidity 0.8+**, **SafeMath** (pré-0.8), **mulDiv** para precisão, **oráculos robustos** e **fuzzing**. Como disse a Hacken: *"Hackers evoluem, mas devs preparados vencem!"* Vamos consertar o odômetro da Web3? 💪

> ❓ *Pergunta Interativa*: "Se você fosse dev do BeautyChain, quais 3 linhas adicionaria para impedir o overflow?"

---