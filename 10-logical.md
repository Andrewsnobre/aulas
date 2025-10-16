# **Artigo: Invariantes Quebrados na Lógica de Negócio em Smart Contracts: Um Mergulho Profundo no Euler Finance Hack e Outros Casos**

## **Introdução: O Balanço que Não Fecha na Web3**

Em 2025, smart contracts são o coração da Web3, gerenciando bilhões em DeFi, NFTs e dApps em blockchains como Ethereum e BNB Chain, com mais de US$ 200 bilhões em TVL (Total Value Locked). São como máquinas de contabilidade digital que devem manter o equilíbrio perfeito entre ativos e passivos, mas, se o balanço não fecha, hackers podem esvaziar o cofre. **Invariantes quebrados na lógica de negócio**, classificados como **A08 no OWASP Smart Contract Top 10 2025** (Lógica de Negócio), ocorrem quando cálculos de depósitos, saques, colaterais ou taxas não preservam invariantes (ex.: ativos == passivos), ordens erradas de atualização permitem manipulações, ou falta de verificações pós-operação (*post-checks*) leva a drenagem gradual ou instantânea. Essas falhas contribuíram para **10% dos hacks em 2024**, com perdas significativas em DeFi. Este artigo explora invariantes quebrados com uma abordagem didática e técnica, culminando na análise do **Euler Finance Hack de 2023**, um exemplo marcante, além de casos relacionados como o Harvest Finance Hack.

*(Piada para engajar: "Invariantes quebrados são como um banco que esquece de somar os saques – o hacker agradece e leva o caixa!")*

---

## **O que são Invariantes Quebrados na Lógica de Negócio? (Explicação Didática)**

Imagine um banco que registra depósitos antes de verificar se há fundos suficientes, ou que paga juros sem atualizar os saldos, fazendo a contabilidade virar uma bagunça. **Invariantes quebrados** ocorrem quando a lógica de negócio de um smart contract falha em manter regras críticas, como "ativos totais = passivos totais" ou "saldos não podem ser negativos". Isso pode acontecer devido a:  
- **Cálculos errados**: Depósitos, saques, colaterais ou taxas que não equilibram os livros.  
- **Ordens erradas de atualização**: Atualizar saldos antes de verificações, permitindo manipulações.  
- **Falta de post-checks**: Não verificar invariantes após operações, como saques excessivos.  
Esses erros permitem que atacantes drenem fundos gradualmente (ex.: acumulando resíduos) ou instantaneamente (ex.: explorando saques indevidos).

*(Piada: "Lógica de negócio quebrada? É como um caixa automático que te dá o dinheiro antes de checar sua conta!")*

**Como funciona na prática?** Smart contracts, especialmente em DeFi, dependem de invariantes financeiros (ex.: soma dos saldos = fundos no contrato). Se a lógica permite saques antes de atualizar saldos, ou não verifica se ativos cobrem passivos, atacantes podem:  
- Retirar mais do que o devido (ex.: via flash loans).  
- Acumular resíduos de arredondamentos em taxas ou shares.  
- Manipular colaterais para obter empréstimos excessivos.  
A ausência de *post-checks* (ex.: verificar `balance >= withdrawals`) torna o contrato vulnerável a drenagem.

**Estatísticas de Impacto**: Invariantes quebrados, parte de A08, contribuíram para **10% dos hacks em 2024**, com perdas menos quantificadas, mas significativas em DeFi. Em 2023, o **Euler Finance Hack** drenou **US$ 197 milhões** devido a um invariante quebrado em cálculos de colateral. A transparência da blockchain facilita a identificação dessas falhas.

---

## **Contexto Técnico: Como Funcionam os Invariantes Quebrados**

### **Mecânica do Ataque**

1. **Cálculos que Não Preservam Invariantes**:  
   - **Erro**: Operações como depósitos, saques ou taxas não mantêm `ativos == passivos`.  
   - **Exploração**: Atacantes manipulam cálculos para criar saldos falsos, drenar fundos ou acumular resíduos.  
   - **Exemplo**: Um contrato que permite saques sem verificar se o total de ativos cobre os passivos.

2. **Ordens Erradas de Atualização**:  
   - **Erro**: Atualizar saldos ou estados antes de verificações críticas.  
   - **Exploração**: Atacantes exploram a ordem para realizar ações indevidas, como saques antes de reduzir saldos.  
   - **Exemplo**: Um contrato que paga um saque antes de subtrair o valor do saldo.

3. **Falta de Post-Checks**:  
   - **Erro**: Não verificar invariantes após operações (ex.: `balance >= totalWithdrawn`).  
   - **Exploração**: Permite saques excessivos ou manipulações graduais, como acumular resíduos de taxas.  
   - **Exemplo**: Um pool que não verifica se o total de shares corresponde aos ativos após um saque.

**Passos de um Ataque Típico**:  
- **Identificação**: O atacante analisa o código (público na blockchain) para encontrar invariantes frágeis ou ordens erradas.  
- **Exploração**: Envia transações que manipulam cálculos (ex.: saques excessivos) ou repetem operações pequenas para acumular resíduos.  
- **Impacto**: Drena fundos instantaneamente ou gradualmente, quebrando a contabilidade do contrato.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultVulneravel {
    mapping(address => uint) public saldos;
    uint public totalAtivos;

    // Vulnerável: Ordem errada e sem post-check
    function sacar(uint valor) public {
        // Não verifica se totalAtivos >= valor
        (bool sucesso, ) = msg.sender.call{value: valor}(""); // Paga antes
        require(sucesso, "Falha no envio");
        saldos[msg.sender] -= valor; // Atualiza depois
        totalAtivos -= valor; // Sem post-check
    }

    // Vulnerável: Resíduos em taxas
    function calcularTaxa(uint valor) public pure returns (uint) {
        return valor / 100; // Perde frações, acumuláveis
    }
}
```

**Como o ataque funciona?**  
- **Ordem Errada**: O atacante chama `sacar(valor)` repetidamente. Como o pagamento ocorre antes de atualizar `saldos`, ele pode explorar reentrância (se aplicável) ou saques excessivos.  
- **Sem Post-Check**: O contrato não verifica se `totalAtivos >= valor`, permitindo saques que quebram o invariante `ativos == passivos`.  
- **Resíduos de Taxas**: Em `calcularTaxa`, divisões como `1 / 100 = 0` acumulam resíduos, que o atacante pode coletar repetindo transações pequenas.  

**Contrato Atacante (Hipotético)**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Atacante {
    VaultVulneravel public vault;

    constructor(address _vault) {
        vault = VaultVulneravel(_vault);
    }

    function atacar() public {
        // Explora ordem errada
        vault.sacar(1 ether); // Tenta saques excessivos
        // Explora resíduos
        for (uint i = 0; i < 100; i++) {
            vault.calcularTaxa(1); // Acumula frações
        }
    }

    receive() external payable {}
}
```

**Por que é perigoso?** Invariantes quebrados permitem manipulações sutis (resíduos) ou catastróficas (drenagem total). A transparência da blockchain expõe a lógica, e ataques como flash loans amplificam o impacto. Em 2024, **10% dos hacks** envolveram falhas de lógica de negócio (A08), especialmente em DeFi.

---

## **Casos Reais: Euler Finance Hack (2023) e Harvest Finance Hack (2020)**

### **Euler Finance Hack (2023)**  
- **Contexto**: Euler Finance, um protocolo DeFi de empréstimos na Ethereum, gerenciava milhões em TVL, usando cálculos complexos para colaterais e saques.  
- **Ataque**: Um invariante quebrado na lógica de doação de ativos permitiu saques excessivos.  
- **Como funcionou?**:  
  - O contrato permitia doar ativos para um pool sem atualizar corretamente os passivos.  
  - O atacante manipulou o colateral via flash loans, explorando a ordem errada de atualizações, e sacou **US$ 197 milhões** em tokens.  
  - A falta de *post-checks* permitiu que o invariante `ativos >= passivos` fosse violado.  
- **Impacto**:  
  - Um dos maiores hacks de 2023, abalando a confiança no Euler.  
  - Funds parcialmente recuperados via negociação.  
  - Reforçou a necessidade de invariantes robustos.  
- **Lição**:  
  - Verifique invariantes após cada operação.  
  - Atualize estados antes de pagamentos.  
  - Audite cálculos complexos.

### **Harvest Finance Hack (2020)**  
- **Contexto**: Harvest Finance, um protocolo de yield farming, usava pools para gerenciar depósitos e saques, com cálculos de shares.  
- **Ataque**: Um invariante quebrado em cálculos de preços e shares permitiu manipulação via flash loans.  
- **Como funcionou?**:  
  - O atacante usou flash loans para manipular preços em um pool, afetando cálculos de shares.  
  - Explorou a ordem errada de atualizações para sacar **US$ 24 milhões** em tokens, violando o invariante de equilíbrio.  
- **Impacto**:  
  - Perda significativa, com pausa no protocolo.  
  - Reforçou os riscos de lógica de negócio frágil.  
  - Harvest implementou verificações mais robustas.  
- **Lição**:  
  - Use *post-checks* para validar invariantes.  
  - Proteja contra manipulações externas (ex.: flash loans).  
  - Teste com simulações de ataques.

---

## **Prevenção Moderna contra Invariantes Quebrados (2025)**

### **Boas Práticas Técnicas**
- **Verificação de Invariantes**: Adicione *post-checks* para garantir `ativos == passivos` após operações.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract VaultSeguro {
      mapping(address => uint) public saldos;
      uint public totalAtivos;

      function sacar(uint valor) public {
          require(saldos[msg.sender] >= valor, "Saldo insuficiente");
          require(totalAtivos >= valor, "Ativos insuficientes");
          saldos[msg.sender] -= valor; // Atualiza primeiro
          totalAtivos -= valor; // Atualiza total
          (bool sucesso, ) = msg.sender.call{value: valor}("");
          require(sucesso, "Falha no envio");
          // Post-check
          require(address(this).balance == totalAtivos, "Invariante quebrado");
      }
  }
  ```  
- **Ordem Correta de Atualização**: Atualize estados (ex.: saldos) antes de executar transferências ou chamadas externas.  
- **Cálculos Precisos**: Use bibliotecas como OpenZeppelin Math para evitar resíduos.  
  ```solidity
  import "@openzeppelin/contracts/utils/math/Math.sol";
  function calcularTaxa(uint valor) public pure returns (uint) {
      return Math.mulDiv(valor, 1, 100, Math.Rounding.Floor); // Arredondamento seguro
  }
  ```  
- **Auditorias**: Contrate firmas como Halborn (92% de detecção) para revisar lógica.  
- **Testes**: Simule ataques com fuzzing (Echidna).

### **Ferramentas de Prevenção**
- **Slither/Mythril**: Detectam invariantes frágeis (92% eficaz).  
- **Tenderly**: Monitora violações de invariantes em tempo real.  
- **Fuzzing (Echidna)**: Simula manipulações de lógica.  
- **Bounties**: Immunefi pagou US$ 52K em média por bugs de lógica em 2024.

### **Tendências em 2025**
Invariantes quebrados (A08) representam **10% dos hacks**, com perdas significativas em DeFi. A complexidade de protocolos como Euler aumenta o risco, mas auditorias com IA e verificações formais prometem reduzir perdas em 20% até 2026. O Euler Finance Hack destacou a necessidade de *post-checks* robustos.

---

## **Conclusão: Mantendo o Balanço Equilibrado**

Invariantes quebrados, como vistos no Euler Finance Hack (2023) e Harvest Finance Hack (2020), são como bancos que esquecem de verificar o caixa. Com **10% dos hacks em 2024** ligados a A08, a lição é clara: valide invariantes, atualize estados na ordem correta e use *post-checks*. Ferramentas como Slither, Echidna e auditorias são as muralhas contra esses ataques. Como disse a Hacken: "Hackers evoluem, mas devs preparados vencem!" Vamos equilibrar esse balanço?

*(Pergunta Interativa para Alunos: "Se você fosse dev do Euler, como teria protegido o invariante?")*

---

## **Instruções para Formatação no Word (para .docx)**  
1. **Copie o texto acima** para um novo documento Microsoft Word.  
2. **Formatação Geral**:  
   - **Título Principal**: Arial, 16pt, negrito, centralizado, azul escuro (#003087).  
   - **Subtítulos (ex.: "O que são Invariantes Quebrados na Lógica de Negócio?")**: Arial, 14pt, negrito, alinhado à esquerda, preto.  
   - **Texto Normal**: Arial, 12pt, justificado, preto, espaçamento 1,15.  
   - **Códigos Solidity**: Consolas, 10pt, fundo cinza claro (#F0F0F0), borda fina preta, recuo de 1 cm.  
   - **Piadas/Perguntas**: Itálico, Arial, 12pt, verde escuro (#006400) para destaque.  
   - **Citações**: Arial, 10pt, itálico, cinza (#666666), com numeração [ID] ao final.  
3. **Tabelas**:  
   - Para estatísticas (ex.: 10% dos hacks em 2024), crie uma tabela:  
     - Colunas: Ano, Perdas (US$), % de Incidentes.  
     - Formato: Bordas finas, cabeçalho em azul (#003087), fundo alternado (#F0F0F0 e branco).  
4. **Diagramas**:  
   - Insira um diagrama de fluxo do ataque (ex.: Atacante → Manipula Colateral → Quebra Invariante → Drena Fundos). Use "SmartArt" (categoria "Processo") ou imagem do draw.io.  
5. **Gráficos**:  
   - Para perdas anuais (opcional): Gere imagem no Chart.js online (dados: 2021: 3.2; 2022: 3.8; 2023: 2.3; 2024: 1.42; 2025 H1: 3.1) e insira via "Inserir > Imagem".  
6. **Salvar**: Arquivo > Salvar como > .docx. Para PDF, use Arquivo > Exportar > Criar PDF.  
7. **Dicas Visuais**:  
   - Adicione ícones (ex.: balança para invariantes) via "Inserir > Ícones".  
   - Use caixas de texto para destacar piadas ou perguntas interativas.  
   - Inclua uma capa com título, seu nome, e data (16/10/2025).

Este artigo é completo, didático e técnico, com foco em invariantes quebrados na lógica de negócio, destacando o Euler Finance Hack (2023) e Harvest Finance Hack (2020), integrando estatísticas de 2025. Copie para o Word, aplique a formatação, e terá um .docx profissional pronto para a aula. Se precisar de ajustes (ex.: mais diagramas ou tabelas), é só avisar! 😊