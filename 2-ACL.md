

# **Artigo: Falhas de Controle de Acesso (ACL) em Smart Contracts**

### **Um mergulho profundo no Bybit Hack e outros casos**

> **Em uma frase:** se a permissão falha, o invasor vira “dono” — e o cofre abre por dentro.

---

## **Introdução — O cofre com a chave debaixo do tapete**

Em **2025**, *smart contracts* seguem como espinha dorsal da **Web3**, movimentando bilhões em **DeFi, NFTs e dApps** em redes como **Ethereum**, **Solana** e **BNB Chain**. Mas cofres digitais só são seguros se as **chaves** e **permissões** forem bem protegidas. **Falhas de Controle de Acesso (ACL)** — funções sensíveis sem *guards* ou chaves administrativas comprometidas — seguem entre os vetores mais explorados. O **Bybit Hack (fev/2025)** tornou isso explícito ao se tornar **o maior roubo cripto da história (~US$ 1,4–1,5 bi)**, com forte componente de **acesso e governança de chaves**; já o **Parity Wallet Hack (2017)** mostrou como um detalhe de inicialização/ACL on-chain permite tomar contratos inteiros. ([AP News][1])

> 😄 **Para engajar:** *Função sem `onlyOwner` é como deixar a porta do banco aberta — com o letreiro “entre sem bater”.*

---

## **O que é uma falha de controle de acesso? (explicação didática)**

Pense num **cofre** cujo painel de controle tem botões “**mint**”, “**upgrade**”, “**pause**”, “**setOracle**”. Se **qualquer um** puder apertá-los (falta de `onlyOwner`/roles) — ou se **alguém roubar a sua chave** (phishing/engenharia social) — o invasor **assume o contrato**: *mint* infinito, *upgrades* maliciosos, pausas/despausas indevidas, *rug* de cofres, etc. Em sistemas multi-sig, **comprometer N de M assinaturas** equivale a **ser o dono** temporário das ações críticas. Esse é o coração das falhas de **ACL**: **quem pode fazer o quê** — no **código** e na **operação**.

---

## **Mecânica das falhas de ACL (on-chain e off-chain)**

* **On-chain (código):** funções críticas sem verificadores de permissão (`onlyOwner`, `AccessControl`) ou padrões mal implementados (ex.: inicialização aberta, *delegatecall* sem *guard*).
* **Off-chain (operações/chaves):** comprometimento de **chaves privadas** (phishing, malware, aprovação cega), falhas de processo em **multi-sig/MPC**, janelas sem **timelock**, ou **aprovações** assinadas sem *out-of-band* verification.

**Fluxo típico do ataque**

1. **Recon**: o invasor lê o código on-chain e/ou mapeia chaves/assinantes.
2. **Exploração on-chain**: chama **funções sem *guard*** (ex.: `mint`, `upgradeTo`, `setOwner`).
3. **Exploração off-chain**: usa **chaves roubadas** para assinar operações administrativas (ex.: *ownership transfer*, *pause/unpause*, *sweeps*).
4. **Efeito**: **dreno de fundos**, *mint* inflacionário ou **controle total** do protocolo.

---

## **Exemplo em Solidity — vulnerável vs. seguro**

### ❌ **ACL vulnerável (sem verificador)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CofreVulneravel {
    address public dono;
    uint256 public fundos;

    constructor() { dono = msg.sender; }

    function depositar() external payable { fundos += msg.value; }

    function sacarTudo() external {              // ❌ sem onlyOwner
        (bool ok, ) = msg.sender.call{value: fundos}("");
        require(ok, "falha envio");
        fundos = 0;
    }

    function atualizarDono(address novo) external { // ❌ qualquer um vira dono
        dono = novo;
    }
}
```

### ✅ **ACL correta (Ownable + timelock opcional)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";

contract CofreSeguro is Ownable {
    uint256 public fundos;

    function depositar() external payable { fundos += msg.value; }

    function sacarTudo() external onlyOwner {
        uint256 v = fundos; fundos = 0;
        (bool ok, ) = owner().call{value: v}("");
        require(ok, "falha");
    }

    function atualizarDono(address novo) external onlyOwner {
        _transferOwnership(novo);
    }
}
```

### ✅ **Papéis granulares (AccessControl)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CofreComRoles is AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
    }

    function pause() external onlyRole(PAUSER_ROLE) { /* ... */ }
    function withdraw(uint256 v, address to) external onlyRole(TREASURER_ROLE) { /* ... */ }
}
```

> ✅ **Boas práticas:** **Ownable/AccessControl**, **timelock + multisig** para ações críticas, **separação de funções**, **pausable** para emergências, e **auditorias** focadas em caminhos administrativos.

---

## **Caso 1 — Bybit Hack (fev/2025): acesso, governança de chaves e o maior roubo cripto**

**Contexto (CeFi + contratos/fluxos on-chain):** A *exchange* **Bybit** sofreu, em **21 de fevereiro de 2025**, **o maior roubo cripto já registrado**: cerca de **US$ 1,4–1,5 bilhão** em **ETH e ativos correlatos**. O episódio ocorreu durante **transferência rotineira** entre carteiras (*cold → warm*), e resultou em **perda maciça** e corrida de saques; a empresa afirmou ter **cobertura** e prometeu ressarcimentos. **FBI** atribuiu a autoria à **Coreia do Norte** (*TraderTraitor/Lazarus*). ([AP News][1])

**O que falhou (resumo técnico de acesso/assinaturas):**
Relatos independentes descrevem **subversão do processo de aprovação** de transações de *cold wallet* (alteração do que os signatários viam), e/ou **engenharia social** para capturar quórum de **assinaturas**. Em ambos os cenários, o **controle efetivo** das ações críticas foi tomado: **assinaturas válidas** autorizaram a transferência de centenas de milhares de ETH para endereços dos invasores — um colapso prático de **ACL operacional** (governança de chaves) mesmo sem bug direto de Solidity. ([NCC Group][2])

**Impacto e repercussão:**

* **Financeiro:** ~**US$ 1,4–1,5 bi** drenados; maior roubo registrado. ([AP News][1])
* **Operacional:** picos de **withdrawals** e medidas de contingência; *bounty/reward* por recuperação. ([The Guardian][3])
* **Atribuição:** **FBI** e análises de risco apontaram **DPRK/Lazarus**. ([Reuters][4])
* **Lição central:** **ACL ≠ só Solidity** — é **código + chaves + processo** (MFA/HSM/MPC, revisão fora de banda, timelocks).

---

## **Caso 2 — Parity Wallet Hack (2017): ACL on-chain e inicialização**

**Contexto:** *Multisig wallet* amplamente usada no ecossistema Ethereum.
**Vetor:** **Inicialização/ACL** em biblioteca compartilhada (uso de `delegatecall`). Uma função de **setup** pôde ser chamada indevidamente, permitindo **tomar *ownership*** e, no episódio de julho/2017, **drenar ~US$ 30–31 milhões em ETH**. Meses depois, outro incidente distinto (“freeze”) congelou centenas de milhões por **`selfdestruct`** em biblioteca — ambos ressaltando **governança de código e ACL**. ([CoinDesk][5])

**Lição central:** funções de **inicialização** e **admin** **jamais** ficam expostas; uso de **Initializable**, *guards* de *upgrade*, e **separação de admin** (proxy *transparent*/UUPS + **timelock**/**multisig**).

---

## **Prevenção moderna (2025) — do código ao processo**

### **No código (on-chain)**

* **Ownable/AccessControl** para toda função sensível; **separação de papéis** (admin vs. tesouraria vs. oráculo).
* **Timelock + Pausable** em operações críticas (tempo de reação e *circuit breaker*).
* **Inicialização segura** em proxies (OpenZeppelin **Initializable**, `initializer`/`reinitializer`).
* **Auditorias** focadas em **caminhos administrativos**, *upgradeability* e *delegatecall*.

### **Na operação (off-chain)**

* **MFA + hardware wallets/HSM** para chaves de *signers*.
* **MPC/multisig** com **quórum robusto** e **políticas de rotação**; **revisão fora de banda** do destino/valor.
* **Controles de mudança** (4-olhos, segregação de funções) e **monitoramento** (alertas de grande risco).
* **Playbooks** de resposta (pausa, *address blocklists*, comunicação, *bounty*).

---

## **Checklist rápido (para colar no repositório)**

1. **Mapeie funções críticas** → `onlyOwner`/**roles** obrigatórios.
2. **Exija timelock + multisig** para *upgrade/mint/sweeps*.
3. **Proteja inicialização** (proxies/libraries) e valide *admin*.
4. **Hardening de chaves**: MFA, HSM/MPC, rotação, *air-gapped*.
5. **Testes/adversarial**: simule chamadas não autorizadas e *role escalation*.
6. **Monitoramento**: alertas para *admin ops*; *dry-run* fora de banda.
7. **Auditorias recorrentes** e **bug bounty** ativos.

---

## **Conclusão — Blindando o cofre digital**

**ACL é o “gate” da Web3**. O **Bybit Hack (2025)** mostrou que **quebras de acesso** (mesmo fora do Solidity) podem superar qualquer bug clássico; o **Parity (2017)** ensinou que **um init aberto** equivale a **entregar a chave**. Segurança real é **socio-técnica**: **código**, **chaves** e **processos**.
Com **Ownable/AccessControl**, **timelocks**, **multisig/MPC**, **auditorias** e **treinamento anti-phishing**, dá para transformar o cofre de vidro em um **cofre de titânio** — e manter a inovação, sem abrir mão da proteção.

> ❓ **Para a turma:** *Se você fosse o responsável por chaves e ACLs hoje, que 3 defesas implementaria antes do próximo deploy?*

---

### **Apêndice — Formatação sugerida (se for para .docx/PDF)**

* **Título:** Arial 16 pt, **negrito**, centralizado, azul-escuro (#003087).
* **Subtítulos (H2/H3):** Arial 14/12 pt, **negrito**.
* **Corpo:** Arial 12 pt, justificado, 1,15.
* **Código:** Consolas 10 pt, fundo cinza (#F4F6F8), borda fina, recuo 1 cm.
* **Callouts (💡/⚠️/✅):** itálico, cinza #555; caixas “**Lição aprendida**”.

---

## **Fontes (seleção)**

* **Bybit (fev/2025):** relatos de ~US$ 1,4–1,5 bi; contexto, atribuição FBI à DPRK; dinâmica da transferência *cold→warm* e corrida de saques. ([AP News][1])
* **Análises adicionais (Bybit):** TRM Labs (mapeamento de fluxos), NCC Group (mecânica de aprovação/assinatura), análises jurídicas/regulatórias. ([TRM Labs][6])
* **Parity Wallet (2017):** perdas (~US$ 30–31M) por ACL/inicialização; “freeze” posterior (congelamento de centenas de milhões). ([CoinDesk][5])
