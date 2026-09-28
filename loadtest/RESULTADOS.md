# Bateria 1 — 10/09/2026

Ambiente: emuladores Firebase (Firestore + Auth), projeto `ecojp-loadtest`,
50 usuários com e-mail verificado, k6 v2.2.0. Rules idênticas às de produção.

## Resumo

| Teste | Resultado | Vale como evidência? |
|---|---|---|
| Contenção de curtidas | 3.659 curtidas, 0 conflitos | **Não** — emulador não reproduz contenção |
| Criação de denúncias | 3.104 criadas, 0 rejeitadas, p95 de 4 ms | Sim |
| Rajada anti-spam | 150 denúncias aceitas em 30 s do mesmo usuário | **Sim — achado confirmado** |
| Leitura por sessão | 520 documentos por sessão | **Sim — achado confirmado** |

## 1. Contenção de curtidas — inconclusivo por limitação do ambiente

Taxa subiu de 1 para 40 curtidas/segundo no mesmo documento durante 4 minutos.

```
Curtidas aceitas ....... 3659
Curtidas em conflito ... 0 (0,0%)
Latência ............... mediana 6 ms · p95 13 ms · máximo 39 ms
Estado final do doc .... likes=42, likedBy=42 uids distintos, 0 duplicados
```

Latência plana e contador consistente indicam que o emulador **serializa** as
transações com trava local em vez de abortar a perdedora, que é o que o
Firestore real faz (concorrência otimista). O emulador também não replica entre
zonas — e é a replicação que impõe o limite de ~1 escrita/segundo por documento
no serviço real.

O script está correto: o smoke test validou beginTransaction, batchGet, commit
e a checagem de consistência não achou atualização perdida. O que falta é o
ambiente. **Repetir contra projeto Firebase real** (passo a passo no README).

## 2. Criação de denúncias — sem gargalo

```
Criadas ................ 3104 em 180 s (17,2/segundo sustentados)
Rejeitadas ............. 0
Validação das Rules .... mediana 3 ms · p95 4 ms · máximo 18 ms
```

As 694 linhas de Rules validam quinze campos por escrita e isso não apareceu
como custo. Denúncias são documentos novos, sem contenção — esta parte escala.

## 3. Anti-spam — ACHADO CONFIRMADO

Um único usuário, 5 denúncias por segundo durante 30 segundos:

```
Rajadas aceitas ........ 150 de 150
```

O app declara intervalo mínimo de 30 segundos entre denúncias do mesmo usuário.
O servidor aceitou **150 denúncias em 30 segundos** — 300 vezes o ritmo
permitido. Confirma que o `RateLimiter` (`lib/services/rate_limiter.dart:14`) é
um `Map` em memória no cliente, sem contraparte no servidor.

Correção: mover a validação para Cloud Function ou para as Rules, comparando
com o carimbo de tempo da última denúncia do autor.

## 4. Leitura por sessão — ACHADO CONFIRMADO

```
Documentos lidos ....... 4.490.720
Sessões simuladas ...... 8.636
Por sessão ............. 520
```

Confirma a estimativa da auditoria: 20 documentos do feed mais 500 de uma tela
agregada (mapa, estatísticas ou dados públicos). Um usuário que abre duas
dessas telas passa de mil leituras numa sessão.

Dimensão do custo: esta execução de dois minutos consumiu o equivalente a
**noventa dias da cota gratuita** do Firebase (50 mil leituras/dia), ou cerca
de R$ 15 se tivesse rodado contra o projeto real. É a razão de a suíte apontar
para o emulador por padrão.

## Próxima bateria

Repetir os testes 1, 3 e 4 depois das correções, para ter o par antes/depois:

- reações em `ocorrencias/{id}/reacoes/{uid}` com `FieldValue.increment`
- limite de taxa no servidor
- documento agregado de estatísticas em lugar das três consultas de 500
