# 📘 Segurança em Smart Contracts: O Guia  como História  
**Revisão completa para a prova 
---

Imagine que você acabou de deployar seu primeiro contrato de DeFi na mainnet. É um vault simples: usuários depositam ETH, o contrato consulta o preço do token em uma pool da Uniswap, calcula recompensas e permite saque com bônus. Tudo testado na Goerli. Tudo perfeito.  

Três horas depois, o saldo do contrato é zero.  

Como isso aconteceu?  

Vamos descobrir **juntos**, como se estivéssemos debugando ao vivo — e, no caminho, vmaos  absorver tudo o que precisamos para a prova, sem perceber que estamos revisando.

---

Tudo começou na **mempool**. Quando o primeiro usuário enviou 10 ETH com a função `deposit()`, a transação não entrou no bloco imediatamente. Ficou lá, exposta, visível para qualquer nó da rede. Um bot viu: “endereço X quer depositar 10 ETH às 14:32”. Ele copiou a chamada, aumentou o *gas* em 300% e entrou no bloco **antes**. Quando a transação original foi minerada, o preço já tinha sido manipulado. Isso não é sorte. É **execução antecipada de uma transação antes de outra na mempool** — o que chamamos de *frontrunning*.

O bot não parou aí. Ele pegou um *flash loan* de $500 milhões, comprou o token no pool que seu contrato usava como referência de preço, inflou o valor em 18% **por um único bloco**, e seu contrato — que lia o preço spot — achou que o usuário merecia 50x mais recompensas. Quando o *flash loan* foi devolvido, o preço voltou ao normal. Mas o dano estava feito. Isso não foi reentrância, nem overflow. Foi **manipulação de oráculo**.

Você olha o código e pensa: “Mas eu usei um oráculo!”. Na verdade, você usou uma leitura direta da pool. Oráculos de verdade — como Chainlink — agregam dados de várias fontes e resistem a ataques de um bloco. Preços spot? São brinquedos nas mãos de quem tem capital temporário.

---

Vamos voltar ao código. Você usou uma biblioteca externa para cálculos complexos, chamando via `delegatecall`. Funcionou bem na testnet. Mas a biblioteca tinha uma função pública de inicialização. Um atacante chamou essa função **direto na biblioteca**, assumiu controle e, com um `delegatecall` reverso, sobrescreveu o `owner` do seu vault. Depois, executou `SELFDESTRUCT`.  

O que `SELFDESTRUCT` faz? **Remove o bytecode do contrato da chain para sempre e envia todo o saldo para um endereço escolhido**. Não congela, não copia, não volta atrás. Seu contrato simplesmente **desapareceu**. E o pior: o atacante fez isso porque `delegatecall` **executa código externo usando o storage do contrato atual**. Essa é a armadilha.

---

Você tenta recuperar os logs. Olha o timestamp do bloco do ataque: 14:32:12. Mas o bloco anterior foi 14:31:58, e o próximo, 14:32:28. Estranho. Alguém **ajustou o `block.timestamp` em alguns segundos** — algo que mineradores podem fazer dentro dos limites do protocolo. Seu contrato usava `block.timestamp` para liberar bônus após “exatamente 24 horas”. Um validador atrasou 3 blocos. Usuários perderam o bônus. Outros, com blocos adiantados, sacaram antes da hora.

`block.timestamp` **não é um relógio real**. Nunca use para precisão fina. Para janelas grandes, use `block.number`. Para aleatoriedade, use oráculos ou *commit-reveal*.

---

Você decide reescrever o contrato. Agora, quer testar melhor. Escreve 40 testes unitários. Tudo passa. Mas ainda está com medo.  

Você ativa **fuzzing automatizado com Echidna**. Em 6 horas, a ferramenta gera 120.000 entradas aleatórias. Uma delas: um valor de `2**256 - 1` passado como `amount`. O cálculo de recompensa dá overflow silencioso (Solidity 0.8+ tem checagem, mas você desativou com `unchecked`). O contrato aprova mint de 10¹⁰ tokens. Testes manuais nunca pegariam isso. **Echidna** pegou.

---

No novo código, você protege o saque com uma função `withdraw()`. Mas esquece a ordem. Primeiro envia o ETH, depois zera o saldo. Um contrato malicioso chama `withdraw()`, recebe o ETH, e na `fallback()` chama `withdraw()` de novo — **antes do saldo ser atualizado**. Isso é reentrância. O padrão que evita isso? **Checks → Effects → Interactions**: valide tudo, atualize o estado **antes**, só depois interaja com o mundo externo.

---

Enquanto isso, um usuário tenta depositar 1 wei “de brincadeira”. Seu contrato aceita, adiciona ao saldo, mas não valida. Outro envia 1000 ETH por engano — e não tem como reverter. **Nunca confie em `msg.value`**. Sempre valide: `require(msg.value > 0 && msg.value <= maxDeposit)`.

---

Você adiciona uma `fallback()` para aceitar ETH direto. Mas coloca lógica pesada dentro: um loop que atualiza estatísticas. Um atacante envia 1 wei com 10.000 bytes de dados. A `fallback()` tenta processar tudo. **Gas estourado**. Ninguém mais consegue interagir. Isso é **DoS por consumo excessivo de gas ou bloqueio de execução**. Mantenha `fallback()` e `receive()` **mínimas ou inexistentes**.

---

Um phishing convence um usuário a interagir com um contrato malicioso. Esse contrato chama seu vault com uma função de emergência. Você usou `tx.origin` para autenticação:  
```solidity
if (tx.origin == owner) { emergencyWithdraw(); }
```  
`tx.origin` é quem **iniciou** a transação. O usuário iniciou. O contrato malicioso chamou. **Permissão concedida**. O atacante drena tudo. **Use `msg.sender`**.

---

Alguém tenta fazer swap com um endereço truncado: 19 bytes em vez de 20. A EVM preenche com zero. O parâmetro seguinte (`amount`) é lido como parte do endereço. Aprovação de bilhões. Isso é o **short address attack**, explorando **tamanho incorreto de parâmetros ABI**.

---

Você grava o histórico de depósitos com `SSTORE`. Cada operação custa 20.000 *gas*. Em uma hora, o contrato fica caro demais. **SSTORE escreve no storage persistente** — é caro, eterno e irreversível. Planeje com *packing*, use memória quando possível.

---

O atacante tenta o mesmo golpe na Binance Smart Chain. A transação assinada na Ethereum funciona lá também. **Replay attack**: **reutilização de uma transação válida em outra chain ou contexto**. A defesa? Inclua `chainId` na assinatura (EIP-155).

---

Você consulta o Yul intermediário para otimizar *gas*. Descobre que o compilador transformou uma checagem segura em uma operação direta. Um bug silencioso. **Yul é a camada entre Solidity e os opcodes da EVM**. Entendê-lo evita surpresas.

---

Um auditor externo roda fuzzing e encontra uma forma de mint ilimitado. Ele **notifica você em particular, envia uma PoC clara, documenta impacto e sugere correção**. Não publica no Twitter. Não ignora. Age com responsabilidade.

---

Você faz uma chamada externa para transferir tokens:  
```solidity
token.call(abi.encodeWithSignature("transfer(...)"));
```  
Não verifica o retorno. O token está pausado. A transferência falha. Seu contrato continua como se tudo estivesse bem. **Sempre valide o endereço, cheque o retorno, trate falhas**.

---

Você testa tudo na Goerli. Tudo perfeito. Deploy na mainnet. Um erro de *gas* custa $200. Um bug drena $2 milhões. **Mainnet tem risco real de perda de fundos e custo de gas**. Teste em *fork local*, use Anvil, Hardhat, fuzzing, auditoria externa.

---

Por fim, você deixa a função `mint()` pública “só para testes”. Alguém chama. Emite 1 bilhão de tokens. Preço cai 99%. **Funções como `mint()` nunca devem ser públicas**. Use `onlyOwner`, *multisig*, *timelock* ou governança.

---
