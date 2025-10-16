# ⚖️ **Construindo Web3 Segura: Invariantes Quebrados na Lógica de Negócio em Smart Contracts**

> *"Invariantes quebrados são como um banco que esquece de somar os saques – o hacker agradece e leva o caixa!"*  
> — *Inspirado por Hacken: "Hackers evoluem, mas devs preparados vencem!"* 🛡️

Em **2025**, a Web3 pulsa com **mais de US$ 200 bilhões em TVL** em DeFi, NFTs e dApps, rodando em blockchains como **Ethereum** e **BNB Chain**. Smart contracts são **máquinas de contabilidade digital**, mas, se o balanço não fecha, hackers esvaziam o cofre. **Invariantes quebrados na lógica de negócio**, classificados como **A08 (Lógica de Negócio)** no **OWASP Smart Contract Top 10 2025**, ocorrem quando cálculos ou ordens de atualização falham em manter regras críticas (ex.: `ativos == passivos`). Essas falhas contribuíram para **10% dos hacks em 2024**, com perdas significativas em DeFi. Este artigo explora invariantes quebrados com uma abordagem **didática e técnica**, analisando o **Euler Finance Hack (2023)** e o **Harvest Finance Hack (2020)**, com práticas para equilibrar a Web3. Vamos fechar o balanço? 💪

---

## 🚨 **O que são Invariantes Quebrados na Lógica de Negócio?**

Imagine um banco que paga saques antes de verificar o saldo, ou que calcula juros sem atualizar os passivos, bagunçando a contabilidade. **Invariantes quebrados** ocorrem quando a lógica de negócio de um smart contract falha em manter condições críticas, como `ativos == passivos` ou `saldos >= 0`. Isso acontece por:  
- **Cálculos Errados**: Depósitos, saques ou taxas que desequilibram os livros.  
- **Ordem Errada**: Atualizar estados após ações (ex.: pagar antes de reduzir saldo).  
- **Falta de Post-Checks**: Não verificar invariantes após operações.

> 😄 *Piada*: "Lógica quebrada? É como um caixa automático que te dá dinheiro antes de checar sua conta!"

**Como funciona na prática?** Contratos DeFi dependem de invariantes financeiros (ex.: soma dos saldos = fundos no contrato). Falhas permitem:  
- **Saques Excessivos**: Retirar mais do que o devido, via flash loans.  
- **Resíduos**: Acumular frações de taxas ou shares.  
- **Manipulação de Colaterais**: Obter empréstimos indevidos.  

**Estatísticas de Impacto**: Invariantes quebrados (A08) causaram **10% dos hacks em 2024**, com perdas significativas em DeFi. O **Euler Finance Hack (2023)** drenou **US$ 197M** devido a um invariante violado.

---

## 🛠 **Contexto Técnico: Como Funcionam os Invariantes Quebrados**

### **Mecânica do Ataque**

1. **Cálculos Errados**  
   - **Erro**: Operações (ex.: saques, taxas) não mantêm `ativos == passivos`.  
   - **Exploração**: Atacantes criam saldos falsos ou acumulam resíduos.  
   - **Exemplo**: Saque sem verificar se `totalAtivos >= valor`.

2. **Ordem Errada de Atualização**  
   - **Erro**: Atualizar saldos após transferências ou chamadas externas.  
   - **Exploração**: Permite saques indevidos ou reentrância (se aplicável).  
   - **Exemplo**: Pagar antes de reduzir `saldos`.

3. **Falta de Post-Checks**  
   - **Erro**: Não validar invariantes após operações.  
   - **Exploração**: Saques excessivos ou manipulações graduais.  

**Passos de um Ataque Típico**:  
1. **Análise**: Atacante examina código público por invariantes frágeis.  
2. **Exploração**: Envia transações que manipulam cálculos (ex.: flash loans) ou acumulam resíduos.  
3. **Impacto**: Drena fundos ou corrompe contabilidade.

### **Exemplo de Código Solidity Vulnerável**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultVulneravel {
    mapping(address => uint) public saldos;
    uint public totalAtivos;

    function sacar(uint valor) public {
        // Vulnerável: Ordem errada, sem post-check
        (bool sucesso, ) = msg.sender.call{value: valor}("");
        require(sucesso, "Falha");
        saldos[msg.sender] -= valor; // Atualiza depois
        totalAtivos -= valor; // Sem verificar invariante
    }

    function calcularTaxa(uint valor) public pure returns (uint) {
        return valor / 100; // Perde frações
    }
}
```

**Como o ataque funciona?**  
- **Ordem Errada**: O atacante chama `sacar` repetidamente, explorando o pagamento antes da atualização de `saldos`.  
- **Sem Post-Check**: Não verifica `address(this).balance == totalAtivos`, permitindo saques excessivos.  
- **Resíduos**: `calcularTaxa` perde frações, acumuláveis por repetição.

**Contrato Atacante**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Atacante {
    VaultVulneravel public vault;

    constructor(address _vault) {
        vault = VaultVulneravel(_vault);
    }

    function atacar() public {
        vault.sacar(1 ether); // Explora ordem
        for (uint i = 0; i < 100; i++) {
            vault.calcularTaxa(1); // Acumula resíduos
        }
    }

    receive() external payable {}
}
```

**Por que é perigoso?** A transparência da blockchain expõe lógica frágil, e flash loans amplificam ataques. Invariantes quebrados causaram **10% dos hacks em 2024**.

---

## 📊 **Casos Reais: Euler Finance Hack (2023) e Harvest Finance Hack (2020)**

### **Euler Finance Hack (2023)**  
- **Contexto**: Protocolo DeFi na Ethereum, gerenciando empréstimos e colaterais.  
- **Ataque**: Invariante quebrado em doações de ativos permitiu saques excessivos.  
- **Como funcionou?**:  
  - Função de doação não atualizava passivos corretamente.  
  - Atacante usou flash loans para manipular colaterais, drenando **US$ 197 milhões**.  
  - Falta de *post-check* violou `ativos >= passivos`.  
- **Impacto**:  
  - Um dos maiores hacks de 2023.  
  - Fundos parcialmente recuperados.  
- **Lição**:  
  - Valide invariantes após operações.  
  - Atualize estados antes de transferências.  
  - Audite cálculos complexos.

### **Harvest Finance Hack (2020)**  
- **Contexto**: Protocolo de yield farming com pools e cálculos de shares.  
- **Ataque**: Invariante quebrado em preços e shares permitiu manipulação.  
- **Como funcionou?**:  
  - Flash loans manipularam preços, afetando shares.  
  - Ordem errada de atualizações permitiu dreno de **US$ 24 milhões**.  
- **Impacto**:  
  - Perdas significativas, protocolo pausado.  
  - Reforçou necessidade de *post-checks*.  
- **Lição**:  
  - Use *post-checks* para invariantes.  
  - Proteja contra manipulações externas.

---

## 🛡️ **Prevenção Moderna contra Invariantes Quebrados (2025)**

### **Boas Práticas Técnicas**  
- **Post-Checks** 🔒  
  - Valide invariantes após operações.  
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract VaultSeguro {
      mapping(address => uint) public saldos;
      uint public totalAtivos;

      function sacar(uint valor) public {
          require(saldos[msg.sender] >= valor, "Saldo insuficiente");
          require(totalAtivos >= valor, "Ativos insuficientes");
          saldos[msg.sender] -= valor;
          totalAtivos -= valor;
          (bool sucesso, ) = msg.sender.call{value: valor}("");
          require(sucesso, "Falha");
          require(address(this).balance == totalAtivos, "Invariante quebrado");
      }
  }
  ```  
- **Ordem Correta** ⏳  
  - Atualize estados antes de transferências.  
- **Cálculos Precisos**: Use `Math.mulDiv` para evitar resíduos.  
  ```solidity
  import "@openzeppelin/contracts/utils/math/Math.sol";
  function calcularTaxa(uint valor) public pure returns (uint) {
      return Math.mulDiv(valor, 1, 100, Math.Rounding.Floor);
  }
  ```  
- **Auditorias**: Contrate Halborn (92% de detecção).  
- **Testes**: Simule com Echidna.

### **Ferramentas de Prevenção**  
- **Slither/Mythril**: Detectam invariantes frágeis (92% eficaz).  
- **Tenderly**: Monitora violações de invariantes.  
- **Fuzzing (Echidna)**: Testa manipulações.  
- **Bounties**: Immunefi pagou **US$ 52K médio** por bugs em 2024.

### **Tendências em 2025**  
Invariantes quebrados (A08) causaram **10% dos hacks**, com impacto em DeFi. Auditorias com IA e verificações formais prometem reduzir perdas em **20% até 2026**.

---

## 🎯 **Conclusão: Mantendo o Balanço Equilibrado**

Invariantes quebrados, como no **Euler Finance Hack (2023)** e **Harvest Finance Hack (2020)**, são falhas contábeis que abrem o cofre da Web3. Com **10% dos hacks** ligados a A08, a solução é clara: use **post-checks**, atualize estados corretamente e audite cálculos. Ferramentas como Slither, Echidna e Tenderly são as muralhas contra esses ataques. Como disse a Hacken: *"Hackers evoluem, mas devs preparados vencem!"* Vamos equilibrar esse balanço? 💪

> ❓ *Pergunta Interativa*: "Se você fosse dev do Euler, como teria protegido o invariante?"

---