Aqui está o seu **artigo revisado, padronizado e “mais bonito”**, com headings consistentes, exemplos Solidity (vulnerável vs. seguro), explicação didática + técnica e **fontes citadas** nos pontos críticos. Pronto para colar em slides, PDF ou .docx.

---

# **Artigo: Validação Insuficiente de Entradas e Anti-Replay em Smart Contracts**

### **Um mergulho profundo no Cetus Hack e outros casos**

> **Em uma frase:** se o contrato não valida **o que** chega nem **se** já chegou antes, atacante repete o golpe — e a cadeia repete o prejuízo.

---

## **Introdução — A porta aberta para o caos na blockchain**

Em **2025**, *smart contracts* sustentam bilhões em **DeFi, NFTs e dApps** em **Ethereum, Solana, Sui, BNB Chain** e outras redes. São cofres automatizados — **mas cofres ainda precisam de trancas**. Entre as classes mais críticas estão a **validação insuficiente de entradas** e a **ausência de mecanismos anti-replay** (unicidade de mensagens). O **Cetus Protocol**, maior DEX da **Sui**, sofreu em **22/mai/2025** um ataque de **~US$ 223 milhões** associado a um **bug aritmético/checagem insuficiente** numa biblioteca de cálculo usada pelos *pools* — um lembrete de que **verificar parâmetros e invariantes** é vital mesmo “no detalhe matemático”. ([The Defiant][1])

Bridges e mensageria *cross-chain* também mostram por que **anti-replay** é obrigatório: **Wormhole (fev/2022)** perdeu ~**120k wETH (~US$ 320–326M)** quando a verificação de provas/assinaturas foi contornada; **Nomad (ago/2022)** ilustrou **replays em massa** de uma mesma “mensagem”, drenando ~**US$ 190M**. ([Halborn][2])

> ⚠️ **Nota sobre estatísticas:** o OWASP SC Top 10 (edição atual) publica perdas por categoria; valores variam por metodologia e período. Use os números **com citação** e ajuste para seu material. ([OWASP][3])

---

## **O que é validação insuficiente & anti-replay? (explicação didática)**

* **Validação insuficiente de entradas**: o contrato **aceita parâmetros perigosos** (endereços nulos, *amounts* fora de faixa, *ids* inexistentes) ou **não confere invariantes** (limites, domínios, origem).
  **Analogia:** um caixa eletrônico que libera retirada de “R$ 1 bilhão” sem checar o saldo.

* **Ausência de anti-replay**: **a mesma mensagem/ordem** pode ser **reusada** (na mesma cadeia ou em outra), por falta de `nonce`, `chainId`, `emitter` e marcação `processed`.
  **Analogia:** reutilizar o **mesmo bilhete** para entrar no show várias vezes.

> 😄 **Para engajar:** *Sem validação, o contrato é um caixa que pergunta “vai querer quanto hoje?” — e sem anti-replay ele deixa você voltar no balcão com o mesmo recibo.*

---

## **Como o ataque acontece (visão técnica)**

1. **Reconhecimento:** atacante lê o código/bytecode e identifica **checks ausentes** (ex.: `address(0)`, limites, origens) ou **mensageria sem unicidade**.
2. **Craft de entrada:** envia parâmetros que **forçam caminhos lógicos** indesejados (ex.: *mint* indevido via cálculo mal protegido) **ou** reenfileira a **mesma mensagem**.
3. **Extração:** repete até **drenar** (se replay não for marcado) ou até **quebrar a contabilidade** (se aritmética/validação falhar).

---

## **Exemplos Solidity — vulnerável vs. seguro**

### ❌ **Validação fraca / sem anti-replay**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TokenVulneravel {
    mapping(address => uint256) public saldo;

    // Sem checks básicos (endereço, faixa, invariantes)
    function transferir(address para, uint256 valor) external {
        require(saldo[msg.sender] >= valor, "saldo insuficiente");
        saldo[msg.sender] -= valor;       // pode underflow em lógicas legadas
        saldo[para]       += valor;       // aceita address(0), abuso de queima etc.
    }

    // Mensageria sem unicidade: mesma (payload) pode ser reprocessada
    function processar(bytes calldata payload) external {
        (address to, uint256 amount) = abi.decode(payload,(address,uint256));
        saldo[to] += amount; // ❌ sem nonce/chainId/emitter/processed
    }
}
```

### ✅ **Validação defensiva + anti-replay completo**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PonteSegura {
    mapping(bytes32 => bool) public processed; // anti-replay
    uint256 public immutable EXPECTED_CHAIN;
    address public immutable TRUSTED_EMITTER;

    constructor(uint256 chainId, address emitter) {
        EXPECTED_CHAIN = chainId;
        TRUSTED_EMITTER = emitter;
    }

    function processar(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 chainId,
        address emitter
    ) external {
        require(to != address(0), "dest invalido");
        require(amount > 0, "valor invalido");
        require(chainId == EXPECTED_CHAIN, "chain invalida");
        require(emitter == TRUSTED_EMITTER, "emissor invalido");

        bytes32 key = keccak256(abi.encode(to, amount, nonce, chainId, emitter));
        require(!processed[key], "replay");
        processed[key] = true;

        // efeitos
        _credit(to, amount);
    }

    function _credit(address to, uint256 amount) internal {
        // ... contabilidade segura (uint256), invariantes, eventos
    }
}
```

> ✅ **Padrões essenciais:** *fail-closed*, checar **domínio/origem**, **nonce único** + **marca de processado**, e **invariantes** (somas, limites) — exatamente o que faltou em vários incidentes *cross-chain*. ([webisoft.com][4])

---

## **Estudo de caso 1 — Cetus Protocol (Sui), mai/2025**

**Contexto:** maior DEX da **Sui**; exploração **rápida (~15 min)** drenou **~US$ 223M**. Análises independentes apontam um **bug aritmético/checagem insuficiente** numa **biblioteca de matemática** usada nos cálculos de liquidez/preço (ex.: *overflow/shift check*), abrindo caminho para **posições manipuladas** e drenagem de *pools*. ([The Defiant][1])

**Como funcionou (resumo técnico):**

1. **Posições com faixas estreitas** + **liquidez massiva** (às vezes via *flash loans*) pressionaram caminhos de cálculo.
2. O **guard** aritmético falhou (ex.: *overflow/checked shift*), **quebrando a invariante** entre depósitos e *shares*.
3. O invasor **repetiu** o padrão em múltiplos *pools*, realizando *swaps* e retiradas até atingir ~US$ 223M. ([Halborn][5])

**Lições aplicáveis a A02:**

* **Valide entradas** que alimentam **caminhos matemáticos** (faixas, *ticks*, fatores de escala).
* **Use libs auditadas** e testes de **property/fuzz** para bordas numéricas.
* **Monitore invariantes** on-chain (alertas quando *shares* ≠ reservas esperadas).
  *(Mesmo sendo um bug aritmético, a raiz mostra **checagens insuficientes** — parte das boas práticas de A02.)*

---

## **Estudo de caso 2 — Wormhole (fev/2022) & Nomad (ago/2022): verificação e anti-replay em bridges**

* **Wormhole (Solana↔Ethereum)**: *deprecated/insecure function* permitiu **burlar verificação de assinaturas**, cunhando **~120k wETH (~US$ 320–326M)** sem lastro. **Validação da prova/assinaturas** falhou. ([Halborn][2])
* **Nomad (multi-chain)**: erro de configuração/validação tornou **quase qualquer mensagem “válida”**, permitindo **replays em massa** por imitadores (*copy-cat*), somando **~US$ 190M** drenados. **Anti-replay**/invariantes foram ignorados. ([Medium][6])

**Lições (bridges/mensageria):** **`nonce`**, **`chainId`**, **`emitter`** e **marcação `processed`** **obrigatórios**; provas assinadas devem **amarrar domínio/escopo**; *quórum* e **rotação de chaves** de validadores/guardians; *kill-switch* e pausas para eventos críticos.

---

## **Checklist de prevenção (2025)**

**Validação de entradas**

* `require(to != address(0))`, `require(amount > 0)`, **limites de faixa** e **sanity checks**.
* Não confie em *defaults*: sempre **documente domínios** (unidades, escala, casas decimais).
* **Invariantes** explícitas (assert/cheques antes e depois).

**Anti-replay & domínios**

* Hash **(to, amount, nonce, chainId, emitter)** e **armazene `processed[hash] = true`**.
* **Expirar mensagens** (timestamp/epoch) e **rejeitar duplicatas**.
* Em bridges, amarre **oráculo/prova** ao **domínio** (source/dest chain, contrato emissor).

**Processo & ferramentas**

* **Auditorias** (múltiplas em impacto sistêmico); **Slither/Mythril** para *linting* estrutural; **Echidna/Foundry** (fuzz/property).
* **Monitoramento** (Tenderly/execução simulada) + alertas de **desvio contábil**.
* **Bug bounty** contínuo (casos recentes mostram que a comunidade descobre o que *tools* não viram).

> 📌 **Referência prática anti-replay:** guia de boas práticas para atribuir **nonce + IDs de cadeia** e marcar mensagens processadas. ([webisoft.com][4])

---

## **Conclusão — Fechando as portas (e os replays)**

O **Cetus Hack (2025)** mostra que **um “detalhe” matemático** sem *guard* pode custar **centenas de milhões**; **Wormhole** e **Nomad** ensinaram que **provas e unicidade** não são opcionais. *Smart contracts* são cofres automáticos: **valide tudo**, **trave replays**, **monitore invariantes** — e tome decisões de engenharia como se **cada parâmetro** pudesse ser usado **contra** você. Com **patterns de anti-replay**, **checagens defensivas** e **auditorias/fuzzing**, dá para transformar o “caixa liberado” num **cofre sério**.

> ❓ **Para a turma:** *Quais campos (exatos) você incluiria no hash de unicidade da sua ponte — e onde gravaria a marcação `processed`?*

---



## **Fontes (seleção)**

* **Cetus (mai/2025):** análises técnicas e cobertura (bug aritmético/checagem): **The Defiant**, **Halborn**, **Elliptic**, **QuillAudits**. ([The Defiant][1])
* **Wormhole (fev/2022):** *bypass* de verificação de assinaturas (120k wETH). ([Halborn][2])
* **Nomad (ago/2022):** *crowdsourced replay* após configuração/validação falhas. ([Medium][6])
* **OWASP SC Top 10 (perdas por categoria):** páginas de referência/visão geral (valores variam por corte temporal). ([OWASP][3])

---


[1]: https://thedefiant.io/news/hacks/cetus-protocol-hit-223-million-hack-162-million-frozen-5-million-bounty-vote-on-c13985eb?utm_source=chatgpt.com "Cetus Protocol Hit by $223 Million Hack; $162 ..."
[2]: https://www.halborn.com/blog/post/explained-the-wormhole-hack-february-2022?utm_source=chatgpt.com "Explained: The Wormhole Hack (February 2022)"
[3]: https://owasp.org/www-project-smart-contract-top-10/?utm_source=chatgpt.com "OWASP Smart Contract Top 10"
[4]: https://webisoft.com/articles/blockchain-bridge-security/?utm_source=chatgpt.com "Blockchain Bridge Security: Risks, Hacks, and How to Protect"
[5]: https://www.halborn.com/blog/post/explained-the-cetus-hack-may-2025?utm_source=chatgpt.com "Explained: The Cetus Hack (May 2025)"
[6]: https://medium.com/immunefi/hack-analysis-nomad-bridge-august-2022-5aa63d53814a?utm_source=chatgpt.com "Hack Analysis: Nomad Bridge, August 2022 | by Immunefi"
