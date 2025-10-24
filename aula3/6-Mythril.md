# Mythril: A Ferramenta de Análise de Segurança para Contratos Inteligentes em Ethereum

Olá! Continuando nossa série de artigos sobre ferramentas essenciais para auditoria e desenvolvimento de contratos inteligentes, após explorarmos Slither, Echidna e Foundry, agora é a vez de **Mythril**. Essa ferramenta é um pilar na detecção de vulnerabilidades em contratos Ethereum, usando técnicas avançadas como execução simbólica para caçar bugs que podem custar milhões. Desenvolvida pela ConsenSys Diligence, Mythril é open-source e amplamente usada por auditores e desenvolvedores em 2025, especialmente com o crescimento de DeFi e L2s.

Neste artigo completo, vamos cobrir tudo sobre Mythril: sua origem, funcionamento, instalação, uso prático com exemplos detalhados (incluindo detecção de reentrancy em Solidity), configurações avançadas, integrações e atualizações recentes (até outubro de 2025). Se você é aluno iniciante ou auditor experiente, este guia vai te ajudar a integrar Mythril no seu workflow de segurança. Vamos nessa!

## O que é Mythril?

**Mythril** é uma ferramenta de análise de segurança para contratos inteligentes em **Ethereum e blockchains compatíveis com EVM** (como Polygon, Binance Smart Chain e Arbitrum). Ela usa **execução simbólica** (symbolic execution), resolução de SMT (Satisfiability Modulo Theories) e análise de taint para detectar vulnerabilidades no bytecode EVM, sem precisar do código-fonte original. Lançada em 2016 pela ConsenSys, Mythril explora caminhos de execução possíveis, modelando variáveis como símbolos em vez de valores concretos, o que permite descobrir bugs como reentrancy, overflows e selfdestruct desprotegido.

Diferente de ferramentas estáticas como Slither (que analisa código-fonte), Mythril é dinâmica e simbólica, simulando execuções infinitas para cenários edge-case. Ela não detecta erros de lógica de negócios, mas é excelente para vulnerabilidades SWC (Smart Contract Weakness Classification), como SWC-107 (reentrancy). Em 2025, Mythril é parte do ecossistema MythX (agora evoluído para Diligence Fuzzing), e é usada em audits profissionais para reduzir falsos positivos com heurísticas de branching.

Por que usar Mythril? Em um mundo onde exploits como o DAO hack (2016) custaram bilhões, ela é rápida (análises em minutos) e precisa, detectando issues que fuzzers como Echidna podem perder. Como destacado em tutoriais recentes, "Mythril usa concolic analysis para detectar reentrancy e overflows em Solidity, integrando-se perfeitamente a Truffle e Remix."

## Componentes Principais do Mythril

Mythril é CLI-based (`myth`), com módulos modulares para detecção:

| Componente | Descrição | Uso Principal |
|------------|-----------|---------------|
| **Execução Simbólica (LASER-ETH)** | Motor principal que simula EVM com símbolos. | Exploração de caminhos para detectar violações. |
| **Módulos de Detecção** | Checkers para SWCs (ex.: reentrancy, integer bugs). | `--detect reentrancy` para focar em ataques específicos. |
| **Análise de Taint** | Rastreia fluxos de dados maliciosos (ex.: de `tx.origin`). | Detecção de injeções em chamadas externas. |
| **Integração com Nós** | Suporte a RPC/Infura para análise on-chain. | `myth analyze -a <ENDEREÇO>` para contratos deployados. |

Mythril suporta Solidity >=0.4 e Vyper, e integra com Truffle para projetos multi-contratos.

## Instalação e Configuração Inicial

Instalar Mythril é simples via pip ou Docker, exigindo Python 3.8+ e solc (compilador Solidity).

### Passos para Instalar:
1. **Pré-requisitos**: Instale solc via `solc-select`: `pip install solc-select` e `solc-select install 0.8.24`.
2. **Via Pip (recomendado)**:
   ```
   pip install mythril
   ```
3. **Via Docker (isolado)**:
   ```
   docker pull mythril/mythril
   ```
4. **Atualize**:
   ```
   myth --version  # Deve mostrar 0.23.x+ em 2025
   ```

Para análise on-chain, configure um nó local (Geth) ou Infura: `myth --infura-mainnet`.

### Configuração Básica
Use `--execution-timeout 120` para limitar runtime e `--transaction-count 4` para mais explorações.

## Uso Prático: Do Básico ao Avançado

Mythril roda com `myth analyze <ARQUIVO>`. Vamos usar exemplos com Solidity 0.8.24.

### 1. Exemplo Básico: Detecção de Selfdestruct
Crie `KillBilly.sol` (vulnerável a selfdestruct):
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract KillBilly {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function commencekilling() public {
        if (msg.sender == owner) {
            selfdestruct(payable(owner));  // Desprotegido
        }
    }
}
```

**Rodando Mythril**:
```
myth analyze KillBilly.sol
```
Saída exemplo:
```
==== Unprotected Selfdestruct ====
SWC ID: 106
Severity: High
Contract: KillBilly
Function name: commencekilling()
PC address: 354
Estimated Gas Usage: 974 - 1399
Any sender can cause the contract to self-destruct.
```
Isso detecta que qualquer caller pode acionar selfdestruct se for owner, mas em cenários reais, revela riscos de acesso.

### 2. Exemplo: Detecção de Reentrancy
Crie `VulnerableBank.sol` (clássico reentrancy):
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        uint256 bal = balances[msg.sender];
        require(bal > 0);
        (bool sent, ) = msg.sender.call{value: bal}("");  // Chamada externa antes de update
        require(sent);
        balances[msg.sender] = 0;  // Estado atualizado após
    }
}
```

**Rodando Mythril**:
```
myth analyze VulnerableBank.sol --execution-timeout 120 --transaction-count 3
```
Saída:
```
==== Reentrancy Vulnerability ====
SWC ID: 107
Severity: High
Contract: VulnerableBank
Function name: withdraw()
PC address: 103
A possible reentrancy vulnerability detected.
External call to: user
State variable read before external call: balances[user]
State variable written after external call: balances[user]
```
Mythril usa taint analysis para rastrear que `balances` é lido antes e escrito após a chamada, permitindo reentrância.

### 3. Exemplo: Análise On-Chain
Para um contrato deployado (ex.: endereço 0x5c436ff914c458983414019195e0f4ecbef9e6dd):
```
myth analyze -a 0x5c436ff914c458983414019195e0f4ecbef9e6dd --infura-mainnet
```
Saída: Detecta overflows ou asserts se presentes.

### 4. Exemplo com Truffle
Para projetos Truffle: `truffle compile` seguido de `myth analyze --truffle`.
Isso analisa todos os contratos compilados, gerando relatório verbose com `--verbose-report`.

### 5. Detecção de Assertions
Em `Exceptions.sol`:
```solidity
function assert1() public {
    assert(1 == 2);  // Violação óbvia
}
```
Rode: `myth analyze Exceptions.sol --transaction-count 4`
Saída:
```
==== Exception State ====
SWC ID: 110
Severity: Medium
Contract: Exceptions
Function name: assert1()
PC address: 708
An assertion violation was triggered.
```

## Recursos Avançados

- **Custom Detectors**: Crie módulos Python em `/analysis/modules` para checks personalizados.
- **Branching Heuristics**: Use `--branch-heuristic` para priorizar caminhos em contratos complexos.
- **Integração CI/CD**: GitHub Actions:
  ```yaml
  - name: Run Mythril
    run: myth analyze . --execution-timeout 60
  ```
- **Mythril Pro**: Versão aprimorada com análise de dependências de storage para pruning de caminhos, mais eficiente em 2025.

Como em tutoriais, "Mythril detecta reentrancy rastreando chamadas externas e updates de estado."

## Comparação com Outras Ferramentas

| Ferramenta | Tipo | Velocidade | Foco em Reentrancy | Suporte On-Chain |
|------------|------|------------|--------------------|------------------|
| **Mythril** | Simbólica/Dinâmica | Média (minutos) | Alta (taint analysis) | Excelente (RPC/Infura) |
| **Slither** | Estática | Rápida (<1s) | Média | Não |
| **Echidna** | Fuzzing | Alta | Baixa (propriedades) | Limitada |
| **Manticore** | Simbólica | Lenta | Alta | Boa |
| **Securify** | Estática | Rápida | Alta | Não |

Mythril se destaca em detecções profundas, mas pode ter mais falsos positivos que Slither.

## Melhores Práticas

- **Combine Ferramentas**: Use Slither para estática rápida, Mythril para simbólica profunda.
- **Aumente Transações**: `--transaction-count 10` para mais cobertura, mas monitore timeout.
- **Forneça Fonte**: Sempre use código Solidity para localizações precisas.
- **Para Auditores**: Foque em SWC High Severity; valide manualmente.
- **Evite**: Não use só para lógica de negócios; complemente com testes manuais.
- **CI/CD**: Integre para scans automáticos em pulls.

## Atualizações Recentes (até Outubro 2025)

- **Versão 0.23.x (2024-2025)**: Melhorias em suporte a Solidity 0.8.24+, heurísticas de branching para L2s e integração com Diligence Fuzzing (evolução de Harvey).
- **Mythril Pro**: Nova fork com pruning de storage, 2x mais eficiente em contratos grandes.
- **Pesquisa**: Usado em estudos de 2025 para detecção de reentrancy em 159 contratos, detectando 11.3% de vítimas. No X, devs destacam: "Mythril é essencial para audits iniciais em Solidity."

## Conclusão

Mythril é uma ferramenta indispensável para análise de segurança em contratos Ethereum, brilhando na detecção de reentrancy e outros exploits via execução simbólica. Em 2025, com otimizações para EVM upgrades, ela complementa perfeitamente Slither e Echidna no ciclo de auditoria. Experimente com os exemplos acima – instale via pip e rode `myth analyze VulnerableBank.sol` para ver reentrancy em ação!

Para mais, confira o [GitHub oficial](https://github.com/ConsenSys/mythril) ou tutoriais como o de Bernhard Mueller. Dúvidas? Comente! Happy auditing! ⚔️
