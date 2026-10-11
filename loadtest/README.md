# Teste de carga do EcoJP com Grafana k6

Mede empiricamente os limites levantados na auditoria de 10/09/2026, para ter
número em vez de opinião quando a reitoria ou o MPPB perguntarem "isso aguenta
quantos usuários?".

## Antes de rodar, três coisas importantes

**1. Isto NÃO roda contra `ecojp-8b952`.** Aquele é o projeto da demonstração.
Um teste de carga lá gera custo real (leitura e escrita são faturadas), enche o
feed de denúncia falsa e pode disparar cota. O `seed.mjs` se recusa a rodar
fora do emulador a menos que você force com `LOADTEST_ALLOW_REAL=1`.

**2. O App Check bloqueia o k6.** O projeto tem imposição de App Check ativa no
Firestore, e o k6 não consegue produzir uma atestação do Play Integrity — todas
as requisições voltariam rejeitadas. No emulador o App Check não é avaliado, o
que é mais um motivo para começar por ele. Para medir contra o Firebase real,
crie um **projeto separado** (`ecojp-loadtest`) com a imposição desligada.

**3. O k6 não reproduz o problema de leitura.** O app usa snapshot listeners; o
k6 fala REST, que não tem listener. Escrita e contenção são reproduzidas
fielmente. Leitura é medida só na abertura da tela. Está anotado dentro de
`k6/feed.js`.

## Instalação

O k6 não vem com o projeto. No Windows:

```
winget install k6 --source winget
```

Depois, as dependências Node (já usadas pelos testes de Rules):

```
npm install
```

## Como rodar

Num terminal, suba os emuladores de Firestore e Auth:

```
npm run emulator
```

Noutro, semeie usuários e a denúncia-alvo:

```
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
npm run loadtest:seed
```

No PowerShell, as variáveis vão antes, em linhas separadas:

```
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
npm run loadtest:seed
```

Isso grava `loadtest/tokens.json` com 50 usuários de e-mail verificado. **Os
tokens expiram em uma hora** — rode o seed de novo antes de cada bateria.

Então:

```
npm run loadtest:curtidas    # contenção de escrita (o teste que importa)
npm run loadtest:denuncias   # vazão de criação + limite anti-spam
npm run loadtest:feed        # leitura por sessão
npm run loadtest:pico        # pico de pessoas simultâneas (sessões completas)
```

Para que `feed.js` e `pico.js` leiam um acervo realista, popule antes 10 mil
denúncias sintéticas (com as mesmas variáveis de emulador do seed):

```
npm run loadtest:corpus
```

Cada um grava o resultado bruto em `loadtest/resultados/` (a pasta é
versionada vazia; os JSON gerados, não).

### Como as métricas são contadas

- `curtidas_conflito` só conta disputa pelo documento: a transação é tentada
  até 5 vezes, como o SDK do app faz, e só conta se todas abortarem (409).
  401/403 (token vencido, Rules) vão para `curtidas_negadas`; falhas de rede ou
  servidor, para `curtidas_erro`. Transações abandonadas recebem `rollback`.
- A curtida grava também `usuarios/{uid}/meta/reacao` (carimbo exigido pelas
  Rules, que limitam uma reação por segundo por usuário).
- As consultas filtram `oculto == false`, como o app — sem o filtro as Rules
  negam a listagem.
- Em `pico.js`, "pessoas simultâneas" vem de `vus` (medido), não de `vus_max`
  (o teto configurado), e curtidas em disputa ficam fora da taxa de erro.
- Em `denuncias.js`, a rajada de spam tem contadores próprios e não entra na
  vazão de criação.

Os números de `RESULTADOS.md` foram medidos antes destas correções; rode as
baterias de novo antes de citá-los.

## O que cada teste responde

| Teste | Pergunta | Achado que valida |
|---|---|---|
| `curtidas.js` | Quantas curtidas por segundo uma denúncia aguenta? | Contenção de ~1 escrita/s por documento |
| `denuncias.js` | A validação das Rules segura o ritmo? O anti-spam existe no servidor? | Limite de taxa é só do cliente (P1) |
| `feed.js` | Quantos documentos cada sessão baixa? | 500 docs por abertura de mapa/estatísticas (P0) |

## Como ler o resultado de `curtidas.js`

O teste sobe a taxa de curtidas de 1 para 40 por segundo. Acompanhe
`curtidas_conflito`: enquanto está baixa, o documento dá conta; quando começa a
subir e não volta, é o teto. O limite `curtidas_conflito_taxa < 1%` **falha de
propósito** na arquitetura atual — é justamente a evidência.

O valor institucional está no antes e depois: rode agora, guarde o resultado,
aplique a correção (reações em `ocorrencias/{id}/reacoes/{uid}` com
`FieldValue.increment`) e rode de novo. Dois gráficos lado a lado provam
maturidade de engenharia melhor que qualquer slide.

## Nota sobre o emulador — medido em 10/09/2026

O emulador reproduz as **Rules** com fidelidade total, mas **não reproduz
contenção de escrita**. Isso foi verificado, não suposto:

`curtidas.js` rodou a 40 curtidas por segundo no mesmo documento e deu **zero
conflitos**, com latência plana (mediana 6 ms, máximo 39 ms) e o contador final
consistente — 42 curtidas, 42 uids distintos, nenhuma atualização perdida.

A explicação é a diferença de implementação: o emulador **serializa** as
transações com trava local, enquanto o Firestore real usa concorrência
otimista e **aborta** a transação perdedora. Além disso o emulador não replica
nada entre zonas, e é justamente a replicação que impõe o limite de ~1 escrita
por segundo por documento no serviço real.

**Consequência prática:** `curtidas.js` só produz resultado válido contra um
projeto Firebase de verdade. No emulador ele serve para validar o script, não
para medir o teto.

`denuncias.js` e `feed.js` não sofrem disso — as perguntas que eles fazem são
sobre Rules e sobre volume de documentos, e o emulador responde as duas
corretamente.

## Para medir contenção de verdade

1. Crie um projeto Firebase separado (sugestão: `ecojp-loadtest`) — **nunca**
   `ecojp-8b952`.
2. Desligue a imposição de App Check nele (Console → App Check → Firestore).
3. Publique as mesmas Rules: `firebase deploy --only firestore:rules --project ecojp-loadtest`.
4. Rode o seed com a chave web do projeto e sem as variáveis de emulador:

   ```
   $env:LOADTEST_ALLOW_REAL="1"
   $env:LOADTEST_PROJECT_ID="ecojp-loadtest"
   $env:LOADTEST_API_KEY="<chave web do projeto>"
   npm run loadtest:seed
   ```

5. `npm run loadtest:curtidas`

Atenção ao custo: `feed.js` sozinho leu 4,49 milhões de documentos em dois
minutos no emulador. Contra o Firestore real isso seriam noventa dias de cota
gratuita, ou cerca de R$ 15 em uma única execução. Comece com estágios curtos.
