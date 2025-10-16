# **Artigo: Overflow/Underflow e Erros Aritméticos em Smart Contracts: Um Mergulho Profundo no BeautyChain Hack e Outros Casos**

## **Introdução: O Odômetro Quebra-Cabeças da Web3**

Em 2025, smart contracts são os alicerces da Web3, gerenciando bilhões em DeFi, NFTs e dApps em blockchains como Ethereum e BNB Chain, com mais de US$ 200 bilhões em TVL (Total Value Locked). São como calculadoras digitais que precisam ser precisas, mas, se os cálculos falham, é como um odômetro de carro que volta a zero ao atingir o limite, criando caos financeiro. **Overflow/underflow e erros aritméticos**, classificados como **A02 no OWASP Smart Contract Top 10 2025** (junto com validação insuficiente), são vulnerabilidades críticas, responsáveis por **20% dos hacks em 2024, totalizando US$ 223 milhões em perdas**. Essas falhas ocorrem quando cálculos mal feitos, especialmente em Solidity anterior à versão 0.8, ou arredondamentos incorretos quebram a contabilidade de shares, juros ou taxas, permitindo que atacantes mintem tokens infinitos ou manipulem saldos. Este artigo explora overflow/underflow e erros aritméticos com uma abordagem didática e técnica, culminando na análise do **BeautyChain (BEC) Hack de 2018**, um exemplo clássico, além de casos relacionados.

*(Piada para engajar: "Overflow é como um odômetro que te dá um carro novo ao zerar – e hackers adoram esse ‘presente’!")*

---

## **O que são Overflow/Underflow e Erros Aritméticos? (Explicação Didática)**

Imagine um velocímetro de carro antigo que só vai até 999.999 km. Ao atingir esse limite, ele volta a 0, como se você tivesse um carro novo! Agora, imagine um banco que usa esse velocímetro para contar seu saldo: se você “gasta” além do limite, seu saldo pode virar um número gigantesco ou até negativo. **Overflow/underflow** em smart contracts é isso: cálculos que excedem os limites de um tipo de dado (ex.: `uint8` vai de 0 a 255) causam "transbordo" (wrap-around), criando saldos absurdos ou negativos. **Erros aritméticos**, como arredondamentos incorretos, também bagunçam a contabilidade, permitindo manipulações em shares (ex.: tokens em pools), juros (ex.: empréstimos DeFi) ou taxas (ex.: swaps).

*(Piada: "Com overflow, hackers mintam mais tokens que estrelas no céu – e de graça!")*

**Como funciona na prática?** Em Solidity anterior à versão 0.8, operações como soma (`+`) ou subtração (`-`) não tinham verificações automáticas de limites. Se um `uint8` (máximo 255) recebia 200 + 100, o resultado “transborda” para 44 (300 - 256 = 44). Um atacante pode explorar isso para mintar tokens ou drenar fundos. Arredondamentos incorretos, como dividir 1 token entre 3 usuários sem lidar com frações, também podem levar a perdas ou ganhos indevidos. Esses erros quebram invariantes financeiros, como a soma de saldos em um pool.

**Estatísticas de Impacto**: Em 2024, overflow/underflow e erros aritméticos contribuíram para **US$ 223 milhões em perdas** (parte de A02), especialmente em contratos legados. Embora Solidity 0.8+ tenha mitigado overflow/underflow com verificações nativas, erros aritméticos persistem, como no **BonqDAO Hack de 2023**, que explorou arredondamentos em shares. A transparência da blockchain torna esses erros alvos fáceis.

---

## **Contexto Técnico: Como Funcionam Overflow/Underflow e Erros Aritméticos**

### **Mecânica do Ataque**

1. **Overflow/Underflow**:  
   - **Erro**: Operações aritméticas (ex.: `+`, `-`, `*`) excedem os limites de tipos de dados (ex.: `uint256` máx. 2^256-1, `uint8` máx. 255) sem verificação, causando wrap-around.  
   - **Exploração**: Atacantes manipulam cálculos para criar saldos negativos (underflow) ou enormes (overflow), permitindo saques indevidos ou minting de tokens.  
   - **Exemplo**: Subtrair 1 de um saldo `uint8` de 0 resulta em 255 (underflow), dando ao atacante um saldo gigante.

2. **Erros Aritméticos (Arredondamento)**:  
   - **Erro**: Divisões ou cálculos imprecisos (ex.: sem suporte a decimais) geram perdas ou ganhos indevidos em shares, juros ou taxas.  
   - **Exploração**: Atacantes exploram arredondamentos para acumular resíduos (ex.: em pools) ou manipular cálculos financeiros (ex.: juros em DeFi).  
   - **Exemplo**: Dividir 1 token entre 3 usuários (1/3 = 0,33) sem arredondamento adequado pode zerar saldos ou deixar resíduos exploráveis.

**Passos de um Ataque Típico**:  
- **Identificação**: O atacante analisa o código (público na blockchain) para encontrar operações aritméticas sem verificações ou arredondamentos mal implementados.  
- **Exploração de Overflow/Underflow**: Envia entradas que forçam transbordo (ex.: somar um valor grande a um `uint`) ou subtração abaixo de zero.  
- **Exploração de Arredondamento**: Repete transações pequenas para acumular resíduos de divisões (ex.: em pools de liquidez).  
- **Impacto**: Minting de tokens, saques indevidos ou manipulação de saldos.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0; // Pré-0.8, sem verificações nativas

contract TokenVulneravel {
    mapping(address => uint8) public saldos; // uint8: 0 a 255

    function transferir(address para, uint8 valor) public {
        // Não verifica overflow/underflow
        require(saldos[msg.sender] >= valor, "Saldo insuficiente");
        saldos[msg.sender] -= valor; // Underflow se valor > saldo
        saldos[para] += valor; // Overflow se saldo[para] + valor > 255
    }

    function calcularJuros(uint valor, uint taxa) public pure returns (uint) {
        // Vulnerável: Divisão imprecisa
        return (valor * taxa) / 100; // Perde frações, acumula resíduos
    }
}
```

**Como o ataque funciona?**  
- **Overflow**: O atacante chama `transferir(destino, 100)` com `saldos[destino] = 200`. Como `200 + 100 = 300 > 255`, o saldo de `destino` vira `44` (300 - 256), manipulando a contabilidade.  
- **Underflow**: O atacante chama `transferir(destino, 1)` com `saldos[msg.sender] = 0`. Como `0 - 1` transborda, o saldo vira `255`, permitindo saques indevidos.  
- **Arredondamento**: Em `calcularJuros`, divisões como `1 * 33 / 100 = 0` (em vez de 0,33) acumulam resíduos, que o atacante pode explorar repetindo transações pequenas.  

**Contrato Atacante (Hipotético)**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract Atacante {
    TokenVulneravel public token;

    constructor(address _token) {
        token = TokenVulneravel(_token);
    }

    function atacar() public {
        // Explora underflow
        token.transferir(address(this), 1); // Saldo vira 255
        // Explora arredondamento
        for (uint i = 0; i < 100; i++) {
            token.calcularJuros(1, 33); // Acumula resíduos
        }
    }
}
```

**Por que é perigoso?** A transparência da blockchain expõe operações aritméticas vulneráveis. Antes do Solidity 0.8, overflow/underflow eram comuns, e erros de arredondamento ainda afetam contratos que manipulam frações (ex.: pools de liquidez). Em 2024, **20% dos hacks** envolveram A02, com perdas significativas em DeFi.

---

## **Casos Reais: BeautyChain (BEC) Hack (2018) e BonqDAO Hack (2023)**

### **BeautyChain (BEC) Hack (2018)**  
- **Contexto**: BeautyChain (BEC) era um token ERC-20 para pagamentos no setor de beleza, rodando na Ethereum. O contrato manipulava grandes quantidades de tokens em transferências em lote.  
- **Ataque**: Um overflow em uma função de transferência em lote permitiu que o atacante mintasse bilhões de tokens.  
- **Como funcionou?**:  
  - A função `batchTransfer` não verificava limites em cálculos de `uint256`.  
  - O atacante enviou uma entrada que causou um overflow, multiplicando saldos para valores astronômicos (ex.: 2^256 tokens).  
  - Transferiu os tokens para exchanges, vendendo-os antes da detecção, causando **perdas de milhões** e colapso do token.  
- **Impacto**:  
  - O preço do BEC caiu a zero.  
  - Exchanges suspenderam o trading do token.  
  - Reforçou a necessidade de verificações aritméticas.  
- **Lição**:  
  - Use Solidity 0.8+ com verificações nativas de overflow/underflow.  
  - Adote bibliotecas como SafeMath para versões antigas.  
  - Audite cálculos críticos.

### **BonqDAO Hack (2023)**  
- **Contexto**: BonqDAO, um protocolo DeFi na Polygon, gerenciava empréstimos e pools com shares baseados em preços de oráculos.  
- **Ataque**: Um erro aritmético em cálculos de shares, combinado com manipulação de oráculo, permitiu saques excessivos.  
- **Como funcionou?**:  
  - O contrato usava divisões imprecisas para calcular shares, acumulando resíduos.  
  - Um atacante manipulou o preço de um token via oráculo, explorando o arredondamento para mintar shares extras.  
  - Drenou **US$ 63 milhões** em tokens.  
- **Impacto**:  
  - Perda significativa, abalando a confiança na BonqDAO.  
  - Destacou riscos de arredondamentos em DeFi.  
  - Funds parcialmente recuperados via negociação.  
- **Lição**:  
  - Use bibliotecas como OpenZeppelin para cálculos precisos.  
  - Teste arredondamentos com fuzzing (ex.: Echidna).  
  - Valide oráculos associados.

---

## **Prevenção Moderna contra Overflow/Underflow e Erros Aritméticos (2025)**

### **Boas Práticas Técnicas**
- **Solidity 0.8+**: Inclui verificações nativas de overflow/underflow, revertendo transações fora dos limites.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract TokenSeguro {
      mapping(address => uint8) public saldos;

      function transferir(address para, uint8 valor) public {
          require(saldos[msg.sender] >= valor, "Saldo insuficiente");
          saldos[msg.sender] -= valor; // Reverte em underflow
          saldos[para] += valor; // Reverte em overflow
      }
  }
  ```  
- **SafeMath (Pré-0.8)**: Use a biblioteca OpenZeppelin SafeMath para verificações manuais.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.7.0;
  import "@openzeppelin/contracts/math/SafeMath.sol";

  contract TokenSeguro {
      using SafeMath for uint8;
      mapping(address => uint8) public saldos;

      function transferir(address para, uint8 valor) public {
          saldos[msg.sender] = saldos[msg.sender].sub(valor); // Reverte em underflow
          saldos[para] = saldos[para].add(valor); // Reverte em overflow
      }
  }
  ```  
- **Arredondamento Seguro**: Use bibliotecas como OpenZeppelin Math para divisões precisas, evitando resíduos.  
  ```solidity
  import "@openzeppelin/contracts/utils/math/Math.sol";
  function calcularJuros(uint valor, uint taxa) public pure returns (uint) {
      return Math.mulDiv(valor, taxa, 100, Math.Rounding.Floor); // Arredondamento seguro
  }
  ```  
- **Auditorias**: Contrate firmas como Halborn (92% de detecção) para revisar cálculos.  
- **Testes**: Simule transbordo e arredondamentos com fuzzing (Echidna).

### **Ferramentas de Prevenção**
- **Slither/Mythril**: Detectam operações aritméticas vulneráveis (92% eficaz).  
- **Tenderly**: Monitora transações com cálculos anômalos.  
- **Fuzzing (Echidna)**: Simula overflow/underflow e erros de arredondamento.  
- **Bounties**: Immunefi pagou US$ 52K em média por bugs aritméticos em 2024.

### **Tendências em 2025**
Overflow/underflow (parte de A02) diminuiu com Solidity 0.8+, mas erros aritméticos persistem, contribuindo para **20% dos hacks em 2024**. Contratos legados e cálculos complexos em DeFi (ex.: shares em pools) são alvos. Auditorias com IA e bibliotecas seguras prometem reduzir perdas em 20% até 2026. O BonqDAO Hack reforçou a necessidade de precisão matemática.

---

## **Conclusão: Consertando o Odômetro Digital**

Overflow/underflow e erros aritméticos, como vistos no BeautyChain Hack (2018) e BonqDAO Hack (2023), são como odômetros quebrados que entregam fortunas aos hackers. Com **20% dos hacks em 2024** ligados a A02, a lição é clara: use Solidity 0.8+, bibliotecas como SafeMath e OpenZeppelin Math, e valide cálculos rigorosamente. Ferramentas como Slither, Echidna e auditorias são as muralhas contra esses erros. Como disse a Hacken: "Hackers evoluem, mas devs preparados vencem!" Vamos calibrar essas calculadoras?

*(Pergunta Interativa para Alunos: "Se você fosse dev do BeautyChain, como teria evitado o overflow?")*

---

## **Instruções para Formatação no Word (para .docx)**  
1. **Copie o texto acima** para um novo documento Microsoft Word.  
2. **Formatação Geral**:  
   - **Título Principal**: Arial, 16pt, negrito, centralizado, azul escuro (#003087).  
   - **Subtítulos (ex.: "O que são Overflow/Underflow e Erros Aritméticos?")**: Arial, 14pt, negrito, alinhado à esquerda, preto.  
   - **Texto Normal**: Arial, 12pt, justificado, preto, espaçamento 1,15.  
   - **Códigos Solidity**: Consolas, 10pt, fundo cinza claro (#F0F0F0), borda fina preta, recuo de 1 cm.  
   - **Piadas/Perguntas**: Itálico, Arial, 12pt, verde escuro (#006400) para destaque.  
   - **Citações**: Arial, 10pt, itálico, cinza (#666666), com numeração [ID] ao final.  
3. **Tabelas**:  
   - Para estatísticas (ex.: US$ 223M em 2024), crie uma tabela:  
     - Colunas: Ano, Perdas (US$), % de Incidentes.  
     - Formato: Bordas finas, cabeçalho em azul (#003087), fundo alternado (#F0F0F0 e branco).  
4. **Diagramas**:  
   - Insira um diagrama de fluxo do ataque (ex.: Atacante → Envia valor grande → Overflow → Saldo gigante). Use "SmartArt" (categoria "Processo") ou imagem do draw.io.  
5. **Gráficos**:  
   - Para perdas anuais (opcional): Gere imagem no Chart.js online (dados: 2021: 3.2; 2022: 3.8; 2023: 2.3; 2024: 1.42; 2025 H1: 3.1) e insira via "Inserir > Imagem".  
6. **Salvar**: Arquivo > Salvar como > .docx. Para PDF, use Arquivo > Exportar > Criar PDF.  
7. **Dicas Visuais**:  
   - Adicione ícones (ex.: calculadora para aritmética) via "Inserir > Ícones".  
   - Use caixas de texto para destacar piadas ou perguntas interativas.  
   - Inclua uma capa com título, seu nome, e data (16/10/2025).

Este artigo é completo, didático e técnico, com foco em overflow/underflow e erros aritméticos, destacando o BeautyChain Hack (2018) e BonqDAO Hack (2023), integrando estatísticas de 2025. Copie para o Word, aplique a formatação, e terá um .docx profissional pronto para a aula. Se precisar de ajustes (ex.: mais diagramas ou tabelas), é só avisar! 😊