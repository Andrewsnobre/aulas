

# **Artigo: Overflow/Underflow e Erros Aritméticos em Smart Contracts**

### **Um Mergulho Profundo no BeautyChain (BEC) Hack e Outros Casos**

> **Em uma frase:** quando a matemática falha no on-chain, o cofrezinho vira peneira.

---

## **Introdução — O Odômetro Quebra-Cabeças da Web3**

Em **2025**, *smart contracts* são os alicerces da **Web3**, administrando dezenas de bilhões em **DeFi, NFTs e dApps** em redes como **Ethereum** e **BNB Chain**, com **> US$ 200 bilhões** em **TVL** (*estimativas citadas*). Pense neles como **calculadoras de alta precisão**: se a conta erra, tudo desanda. É o “odômetro” que volta a zero ao atingir o limite — e *overflow/underflow* fazem exatamente isso no nível binário.

No **OWASP Smart Contract Top 10 2025**, *overflow/underflow* e **erros aritméticos** aparecem junto de **validação insuficiente (A02)** como uma das classes **mais críticas**. Em **2024**, essas falhas responderam por **~20% dos hacks**, somando **~US$ 223 milhões** em perdas (*estimativas citadas*). Embora o **Solidity 0.8+** tenha introduzido **checagens nativas** contra *overflow/underflow*, **erros de arredondamento** e **contabilidade de shares/juros/taxas** seguem perigosos — e alvos fáceis, pois o código é público.

> 💡 **Piada para aquecer a turma:** *Overflow é como ganhar “carro zero” toda vez que o odômetro estoura — e tem atacante que adora concessionária on-chain.*

---

## **O que são Overflow/Underflow e Erros Aritméticos? (Visão Didática)**

* **Overflow/Underflow:** quando uma operação ultrapassa os **limites** do tipo numérico (p. ex., `uint8` vai de 0 a 255).

  * `200 + 100` em `uint8` “transborda”: `300 - 256 = 44`.
  * `0 - 1` em `uint8` “rola” para **255** (*underflow*).
* **Erros aritméticos (arredondamento):** divisões e multiplicações com **perda de precisão**, que **quebram invariantes** financeiros (ex.: distribuição de *shares*, juros, taxas).

  * Dividir **1 token** entre **3** sem lidar com decimais → resíduos exploráveis.

> 🎯 **Intuição:** *Overflow/underflow* cria **saldos absurdos**; *rounding* cria **vazamentos discretos** (centavos viram fortunas quando repetidos milhares de vezes).

---

## **Contexto Técnico — Como o Ataque Acontece**

### 1) Overflow/Underflow (pré-Solidity 0.8)

* **Causa:** operações `+`, `-`, `*` sem verificação automática.
* **Exploração:** forçar transbordo (ex.: somar a um `uint` próximo do limite) ou *underflow* (subtrair de saldo zero).
* **Efeito:** *mint* indireto, saques indevidos, contabilidade corrompida.

### 2) Erros de Arredondamento / Precisão

* **Causa:** divisões inteiras, falta de escala (decimais), *rounding* mal definido.
* **Exploração:** repetição de operações que acumulam resíduos (p. ex., emissão de *shares*), manipulação de preços combinada a matemática imprecisa.
* **Efeito:** *drift* contábil (a soma dos saldos ≠ total do pool).

#### **Fluxo típico do atacante**

1. **Audita o bytecode/código** atrás de operações aritméticas frágeis.
2. **Crafta entradas** que provoquem *overflow/underflow* (ou que maximizem resíduos por *rounding*).
3. **Repete** o padrão (às vezes com *flash loans*) até extrair ganho material.
4. **Realiza swaps/saques** e **lava** a vantagem obtida.

---

## **Exemplos em Solidity — Vulnerável vs. Seguro**

### ❌ **Contrato vulnerável (pré-0.8, sem checagens)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0; // sem checagens nativas de overflow/underflow

contract TokenVulneravel {
    mapping(address => uint8) public saldos; // 0..255 (intencionalmente estreito)

    function transferir(address para, uint8 valor) external {
        require(saldos[msg.sender] >= valor, "saldo insuficiente");
        saldos[msg.sender] -= valor; // underflow se valor > saldo
        saldos[para]       += valor; // overflow se saldos[para] + valor > 255
    }

    function juros(uint valor, uint taxaBps) external pure returns (uint) {
        // impreciso: perde frações (rounding), suscetível a "vazamento de centavos"
        return (valor * taxaBps) / 10_000;
    }
}
```

### ✅ **Versão moderna (Solidity ≥ 0.8)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TokenSeguro {
    mapping(address => uint256) public saldos;

    function transferir(address para, uint256 valor) external {
        require(para != address(0), "dest invalido");
        uint256 s = saldos[msg.sender];
        require(s >= valor, "saldo insuficiente");
        unchecked { saldos[msg.sender] = s - valor; } // opcional: usar checagem nativa (sem unchecked)
        saldos[para] += valor; // reveste se overflow (sem unchecked)
    }
}
```

### ✅ **Pré-0.8 com SafeMath (OpenZeppelin)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TokenSeguroLegacy {
    using SafeMath for uint256;
    mapping(address => uint256) public saldos;

    function transferir(address para, uint256 valor) external {
        saldos[msg.sender] = saldos[msg.sender].sub(valor); // reverte underflow
        saldos[para]       = saldos[para].add(valor);       // reverte overflow
    }
}
```

### ✅ **Arredondamento seguro (mulDiv)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/utils/math/Math.sol";

function calcJuros(uint256 principal, uint256 taxaBps)
    pure returns (uint256)
{
    // mulDiv com arredondamento explícito evita perdas sistemáticas
    return Math.mulDiv(principal, taxaBps, 10_000, Math.Rounding.Floor);
}
```

---

## **Casos Reais — BeautyChain (BEC, 2018) e BonqDAO (2023)**

### **BeautyChain (BEC) — 2018: o “BatchOverflow” que cunhou o impossível**

**Contexto:** token **ERC-20** na Ethereum. A função de **transferência em lote** (*batchTransfer*) apresentava um **overflow** clássico.
**Ataque (simplificado):**

* O cálculo de **`total = value * count`** não tinha *guard*.
* Valores grandes provocavam **overflow**, produzindo montantes “válidos” porém absurdos.
* O atacante “cunhou” **bilhões** de BEC e despejou em **exchanges** antes da detecção.
  **Impacto:** preço desabou; **trading** suspenso; perdas de **milhões** e efeito dominó em listagens.
  **Lições:**
* *Nunca* manipular somas/ multiplicações sem *guards* (pré-0.8).
* **Auditar** rotinas de *batch*, *airdrops* e *mint*.
* Em tokens: validar limites e **invariantes** (soma das posições = *supply*).

> 🔎 **Padrão-tipo (pseudocódigo)**
> `uint total = value * to.length; // overflow`
> `require(bal[msg.sender] >= total);`
> `... distribuir ...`

---

### **BonqDAO — 2023: aritmética + oracle, uma dupla perigosa**

**Contexto:** protocolo DeFi na **Polygon**; *shares* e colaterais calculados com base em **oráculo**.
**Ataque (simplificado):**

* Cálculos de *shares* com **divisão inteira** geravam **resíduos**.
* Manipulando o **preço via oráculo**, o atacante explorou o **rounding** para **mintar *shares* extras** e sacar valor indevido.
  **Impacto:** perdas estimadas na casa de **dezenas de milhões** (muitas fontes citam **~US$ 63M**).
  **Lições:**
* Usar **TWAP/mediana** e **oráculos robustos** (Chainlink) — nunca *spot* frágil.
* **mulDiv** e arredondamento explícito; **fuzzing** para cenários extremos.
* **Invariantes**: a soma das *shares* precisa bater com o *supply*/reserva subjacente.

---

## **Prevenção Moderna (2025) — do Código ao Processo**

### **No Código**

* **Solidity 0.8+**: padrão — *overflow/underflow* revertem.
* **Math explícita**: `Math.mulDiv`, *scaling* por casas decimais (18) e **arredondamento** documentado.
* **Invariantes**: *asserts* e *property tests* (Echidna).
* **Revisões focadas**: *batch*, *loops*, *mint/burn*, *fees* e *interest accrual*.

### **No Processo**

* **Auditorias** recorrentes (2+ firmas quando sistêmico).
* **Fuzzing** contínuo (integração/CI).
* **Bug bounties** — estimular *white hats*.
* **Observabilidade**: alertas para deltas contábeis anômalos.

> ✅ **Checklist rápido:**
> (1) Solidity ≥ 0.8 • (2) `mulDiv`/decimais • (3) Invariantes e *fuzz* • (4) Oráculos robustos • (5) Auditoria + bounty.

---

## **Conclusão — Consertando o Odômetro Digital**

Overflow/underflow e erros aritméticos são **armadilhas antigas** com **impacto atual**. O **BEC/BeautyChain (2018)** mostrou como um *overflow* destrói um token em horas; o **BonqDAO (2023)** lembrou que **precisão** e **oráculos** caminham juntos. Em 2024, **~20%** dos incidentes e **~US$ 223M** estiveram ligados a **A02** (*estimativas citadas*). A receita é clara: **Solidity 0.8+**, **bibliotecas confiáveis**, **testes de propriedade e fuzzing**, **oráculos sólidos** e **auditorias contínuas**.

> ❓ **Pergunta para a turma:** *Se você fosse dev do BeautyChain, quais 3 linhas adicionaria para impedir o overflow?*

---

