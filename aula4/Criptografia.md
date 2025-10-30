
## Sumário da Aula 
1. O que é criptografia e por que a Web3 depende dela?  
2. Criptografia Simétrica – A Chave Única  
3. Criptografia Assimétrica – O Segredo de Dois Lados  
4. Funções Hash – A Impressão Digital do Mundo Digital  
5. Como tudo isso funciona junto na Web3?  
6. Analogias do Mundo Real  
7. Perguntas Frequentes (FAQ Didático)  

---

## 1. O que é criptografia e por que a Web3 depende dela?

> **Criptografia = escrever escondido**  
> Do grego: *kryptós* (oculto) + *gráphein* (escrever)

### Na Web2 (centralizada):
- Você confia no banco, no Google, no Facebook  
- Eles guardam seus dados com senhas e criptografia  
- Se o servidor for hackeado → seus dados vazam

### Na Web3 (descentralizada):
- **Não existe um "banco" confiável**  
- **Você é o banco**  
- **Você guarda suas chaves**  
- Se perder → perdeu tudo  
- Se roubarem → roubaram tudo

> **Criptografia é o alicerce da Web3.**  
> Sem ela, não existe carteira, não existe transação, não existe propriedade.

---

## 2. Criptografia Simétrica – A Chave Única

### Analogia: **Cadeado com uma única chave**

> Você e seu amigo têm **a mesma chave** para abrir o mesmo cadeado.

| Passo | Exemplo |
|------|--------|
| 1. Você tranca uma caixa com a chave | Criptografa uma mensagem |
| 2. Dá a caixa trancada pro amigo | Envia dados criptografados |
| 3. Ele usa **a mesma chave** pra abrir | Descriptografa com a mesma chave |

### Características:
| ✅ Vantagem | ❌ Problema |
|------------|-------------|
| Muito rápido | Como entregar a chave com segurança? |
| Ideal para grandes volumes | Se a chave vazar → tudo comprometido |

### Onde aparece na Web3?
| Uso | Exemplo |
|-----|--------|
| Backup de carteiras | Arquivo JSON criptografado com senha |
| Mensagens privadas | Protocolos como Waku ou Whisper |
| Armazenamento local | Seed phrase criptografada no celular |

> **Resumo:**  
> **Simétrica = uma chave para os dois lados (trancar e abrir)**  
> **Rápida, mas perigosa se a chave for interceptada**

---

## 3. Criptografia Assimétrica – O Segredo de Dois Lados

### Analogia: **Caixa com dois cadeados especiais**

> Você tem **duas chaves**:  
> - **Chave vermelha (privada)** → só você tem  
> - **Chave azul (pública)** → todo mundo pode ter

| Tipo de cadeado | O que faz |
|----------------|----------|
| **Cadeado VERMELHO** | Só a chave vermelha abre |
| **Cadeado AZUL** | Qualquer chave azul pode trancar, mas **só a vermelha abre** |

### Dois usos principais:

#### 1. **Criptografia (confidencialidade)**
> Alguém usa sua **chave azul (pública)** pra trancar uma mensagem  
> Só você, com a **chave vermelha (privada)**, abre

#### 2. **Assinatura digital (autenticidade)**
> Você **assina** com a **chave vermelha (privada)**  
> Qualquer um verifica com a **chave azul (pública)**

| Assinatura | Como funciona |
|-----------|---------------|
| Você assina um documento | "Eu sou o dono dessa carteira" |
| Rede verifica com sua chave pública | "Sim, é mesmo ele" |

### Na Web3: **ECDSA com curva secp256k1**
- Mesmo sistema do Bitcoin e Ethereum  
- A partir de uma **seed phrase (12-24 palavras)** → gera:
  - Chave privada (número gigante)  
  - Chave pública  
  - Endereço (últimos 20 bytes do hash da chave pública)

> **Resumo:**  
> **Assimétrica = duas chaves**  
> - **Pública** → todo mundo vê (endereço da carteira)  
> - **Privada** → só você tem (NUNCA compartilhe!)

---

## 4. Funções Hash – A Impressão Digital do Mundo Digital

### Analogia: **Máquina de moer carne**

> Você coloca um boi inteiro → sai um pacotinho de carne moída  
> **Impossível reconstruir o boi a partir da carne moída**

### Propriedades mágicas do hash:

| Propriedade | Explicação com analogia |
|-----------|-------------------------|
| **Determinística** | Mesmo boi → mesma carne moída |
| **Efeito avalanche** | Tira um pelo do boi → carne moída **totalmente diferente** |
| **Irreversível** | Não dá pra saber se era boi, vaca ou cavalo |
| **Resistente a colisão** | Difícil achar dois bois que geram a mesma carne moída |

### Hash mais usado na Web3: **Keccak-256**
- Não é SHA-256 (do Bitcoin)  
- É o "SHA-3" oficial, mas com nome diferente no Ethereum

### Onde o hash aparece?

| Uso | Exemplo |
|-----|--------|
| Endereços Ethereum | Últimos 20 bytes do Keccak-256 da chave pública |
| Merkle Tree | Provar que uma transação está no bloco |
| Assinaturas | Assina o **hash** da mensagem, não a mensagem inteira |
| Blocos | Hash do bloco anterior → cadeia imutável |

> **Resumo:**  
> **Hash = impressão digital única, rápida e impossível de reverter**  
> **Na Web3: tudo é hash de hash de hash**

---

## 5. Como tudo isso funciona junto na Web3?

### Fluxo completo de uma transação Ethereum:

```
1. Você quer enviar 0.1 ETH
2. Monta a transação (to, value, gas, nonce...)
3. Calcula o HASH da transação → Keccak-256
4. Assina esse HASH com sua CHAVE PRIVADA → Assinatura (r, s, v)
5. Envia: [transação + assinatura] para a rede
6. Rede:
   - Pega a assinatura
   - Recupera sua CHAVE PÚBLICA
   - Verifica se o HASH bate
   - Confirma: "Sim, foi mesmo essa carteira que enviou"
```

> **Ninguém vê sua chave privada**  
> **Mas todos provam que foi você**

---

## 6. Analogias do Mundo Real (Para Fixar)

| Conceito | Analogia |
|--------|---------|
| **Chave privada** | A senha do seu cofre no banco |
| **Chave pública** | O número da sua conta bancária |
| **Assinatura** | Sua assinatura no cheque |
| **Hash** | O selo de lacre de um envelope |
| **Criptografia simétrica** | Dois amigos com a mesma chave de casa |
| **Carteira Web3** | Um cofre que só abre com sua voz + impressão digital |

---

## 7. Perguntas Frequentes (FAQ Didático)

### 1. Posso recuperar minha chave privada se perder a seed phrase?
> **Não.**  
> A seed phrase é a **única forma** de regenerar a chave privada.  
> Perdeu = perdeu para sempre.

### 2. Por que não usamos senhas normais (como do Gmail)?
> Senhas são **centralizadas**.  
> Na Web3, **não existe "esqueci a senha"**.

### 3. Alguém pode descobrir minha chave privada olhando meu endereço?
> **Impossível** (na prática).  
> Seria como tentar adivinhar um número de 78 dígitos só vendo os últimos 10.

### 4. Por que assinamos o *hash* e não a mensagem inteira?
> - Hash é sempre 32 bytes (pequeno e fixo)  
> - Assinatura é mais rápida  
> - Mesma segurança

### 5. Qual a diferença entre hash e criptografia?
| Hash | Criptografia |
|------|--------------|
| Não tem chave | Tem chave |
| Não reverte | Pode reverter (com chave) |
| Prova integridade | Prova confidencialidade |

---

## Conclusão Didática

| Conceito | Papel na Web3 | Frase para guardar |
|--------|---------------|---------------------|
| **Simétrica** | Proteger backups | "Uma chave para dois amigos" |
| **Assimétrica** | Provar quem você é | "Pública para ver, privada para ser" |
| **Hash** | Garantir que nada mudou | "Impressão digital do dado" |

---

## Frase Final (para colar na parede)

> **"Na Web3, você não tem conta. Você tem matemática."**  
> — Satoshi Nakamoto (espírito)
Mask, Ledger, etc)"?**  
Responda: `PRÓXIMA AULA`
