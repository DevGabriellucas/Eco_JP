# ADR 0001 — Manter Firebase; não migrar para Supabase

- **Status:** aceito
- **Data:** 2026-09-10
- **Contexto:** avaliação de uma proposta de stack (Supabase + Postgres + Dio/retrofit
  + Isar) contra o que o EcoJP já é, com meta declarada de 30 mil usuários.

## Decisão

O EcoJP continua em **Firebase (Auth + Firestore + App Check + Crashlytics)** — FCM
(push) ainda não é usado; as notificações são in-app, no Firestore —
com **Cloud Functions Gen 2 em TypeScript** como a camada de servidor que hoje não
existe. Não migramos para Supabase/Postgres.

## Por que não Supabase

A proposta avaliada é boa para um projeto novo. Ela não sobrevive ao fato de o
EcoJP já estar construído:

1. **Offline.** É o argumento decisivo. O caso de uso do app é fotografar descarte
   irregular na rua, às vezes sem sinal. O Firestore dá fila de escrita e cache
   offline sem nenhuma linha de código. O Supabase não dá — resolver isso exige
   PowerSync/ElectricSQL, o que é custo e complexidade novos para recuperar algo
   que já funciona.
2. **Superfície de reescrita.** Migrar significa reescrever as 694 linhas de
   `firestore.rules` como RLS, todo o `lib/services/`, todo o `lib/data/repositories/`,
   o fluxo de Google Sign-In e verificação de e-mail, os testes de Rules e os
   scripts de carga. Semanas de trabalho para chegar ao mesmo produto.
3. **O custo não justifica a troca — ver a comparação abaixo.** O Supabase empata
   ou perde, e cobra piso fixo onde o Blaze cobra zero.
4. **"A conta do Firestore explode com leitura pesada" é um diagnóstico trocado.**
   O que explode no EcoJP é o padrão de leitura, não o Firestore. Ver a seção de
   dívidas abaixo: as mesmas telas vão de ~1.000 para ~60 leituras por usuário/dia
   sem trocar de banco.

## Comparação de custo mensal

Estimativa para 30 mil usuários / ~10 mil DAU, com as dívidas de leitura corrigidas
(sem essa correção, a coluna Firebase sobe para ~$500 — ver a seção de dívidas).

| Item | Firebase Blaze | Supabase Pro | Backend próprio |
|---|---|---|---|
| Backend/compute | Functions Gen2 ~$10 | Pro $25 + compute add-on | 2 servidores $60–80 |
| Banco | Firestore ~$20 | incluso (8 GB) | Postgres gerenciado $60–120 |
| Redis | não se justifica no volume | **não é incluso no Pro** | $15–30 |
| Storage/CDN | R2 ~$15 + Cloudflare free | R2 ~$5 + Cloudflare free | $10–20 |
| Auth | $0 até 50 mil MAU | incluso | build próprio ou Clerk |
| Push (FCM) | $0 | $0 | $0 |
| Crash/analytics | Crashlytics $0 | Sentry ~$26 | ~$26 |
| Maps — render mobile | $0 | $0 | $0 |
| Gemini (moderação) | ~$5 | ~$5 | ~$5 |
| Analítico | BigQuery ~$5 | SQL incluso | incluso |
| Lojas + domínio | ~$9 | ~$9 | ~$9 |
| **Total/mês** | **~$65–90** | **~$70–150** | **~$200–400** |

Três pontos que a comparação superficial erra:

1. **O Blaze não é assinatura.** Ele mantém a mesma cota gratuita do Spark e cobra
   só o excedente. Não existe piso. O Pro do Supabase cobra $25 mesmo com zero
   usuário — no piloto de 500 usuários a conta é ~$9/mês (só as lojas) contra
   ~$34/mês.
2. **Redis não vem no Pro do Supabase.**
3. **Sentry não é diferencial**: seria pago nos dois caminhos, e o Crashlytics já
   cobre crash de graça no caminho atual.

O custo decisivo, porém, não aparece em nenhuma coluna: **3 a 6 semanas de
reescrita**, que entregam o mesmo produto com offline pior.

**Meio-termo, se o objetivo for SQL:** o export do Firestore para o BigQuery dá
consulta relacional completa sobre os mesmos dados por ~$5/mês, sem mover o app.

**O que a proposta acerta e nós perdemos ao ficar:** PostGIS (mapa por raio sai de
graça) e JOIN/`GROUP BY` para os relatórios. Contornos aceitos: geohash com bounding
box para o mapa, e export para BigQuery para o analítico.

## Veredito item a item da proposta

| Item proposto | Decisão | Motivo |
|---|---|---|
| Clean Architecture + feature-first | **Adotar** | Já começou: `lib/features/`, `lib/data/repositories/`. Falta migrar `lib/pages/` |
| Riverpod 2.x + riverpod_generator | **Adotar** | Riverpod já é o padrão do projeto; o code gen é incremento |
| go_router | **Já feito** | `lib/core/router/` |
| freezed + json_serializable | **Adotar, com ressalva** | Os modelos já são tipados e documentados. O ganho real é imutabilidade: `OcorrenciaModel` tem campos mutáveis (`likes`, `userLiked`) que o Riverpod não enxerga mudar |
| Dio + retrofit + interceptor de refresh | **Rejeitar** | O app não tem API REST. Fala com o Firestore por SDK; o único HTTP é o upload ao Cloudinary. Seria peso morto |
| Isar ou drift para cache offline | **Rejeitar** | O Firestore já persiste offline. Uma segunda camada de cache duplica a fonte da verdade. O Isar, além disso, está sem manutenção ativa |
| PostgreSQL + Redis | **Rejeitar** | Consequência da decisão acima. Redis não se justifica neste volume |
| REST + OpenAPI, não GraphQL | **Concordo, sem efeito** | A conclusão é certa, mas o EcoJP não expõe REST |
| Clerk para auth | **Rejeitar** | Substitui um Firebase Auth que funciona, e cobra por isso |
| FCM para push | **Adotar** | Já é a escolha |
| Cloudflare R2 (egress grátis) | **Adotar** | Concordo. É o item de maior economia da lista — mídia é o custo dominante do app |
| Cloudflare CDN/DNS | **Adotar** | Plano free resolve |
| Sentry + PostHog | **Parcial** | Crashlytics + Firebase Analytics já cobrem. PostHog agrega em analytics de produto; Sentry seria redundante |
| Região São Paulo (`southamerica-east1`) | **Verificar — pode ser tarde** | Correto e importante. Mas a região do Firestore é definida na criação e **não pode ser alterada**. Se `ecojp-8b952` não estiver em `southamerica-east1`, mudar exige banco novo + migração. Checar com `firebase firestore:databases:list --project ecojp-8b952` |
| CI/CD Codemagic ou GitHub Actions | **Adotar** | Feito: GitHub Actions (`ci.yml` e `release.yml`) |

## Dívidas que a migração não resolveria (e que valem mais que ela)

Em ordem de retorno, medidas na auditoria de 10/09/2026 e nos testes em
`loadtest/RESULTADOS.md`:

1. **Curtidas em array dentro do doc da ocorrência** (`likedBy`/`dislikedBy`).
   Satura em ~1 escrita/segundo por documento e reenvia o doc inteiro para todo
   cliente com o feed aberto. Correção: subcoleção `reacoes/{uid}` + contador
   mantido por Function.
2. **Rate limit só no cliente.** O `RateLimiter` é um `Map` em memória; o teste de
   carga aceitou 150 denúncias em 30 s de um usuário só, 300× o ritmo declarado.
   Correção: Rules sobre `lastDenunciaAt`, escrito por Function.
3. **Feed pagina aumentando o `limit` de um listener ao vivo**, relendo o que já
   baixou. Correção: `startAfterDocument` com `.get()` nas páginas antigas.
4. **Mapa e estatísticas baixam 500 docs por abertura.** Correção: documento
   agregado mantido por trigger.
5. **Unicidade de nome varria a coleção `usuarios` inteira** — O(n) por cadastro.
   **Corrigido nesta mudança**, ver abaixo.

## Implementado junto com este ADR

Índice `nomes_reservados/{slug}`, um documento por nome, com o slug do nome como ID
(`slugify` de `lib/utils/texto.dart`).

- **Custo:** a checagem de nome sai de N leituras por cadastro para 1. Em 30 mil
  contas, era 30 mil leituras a cada cadastro.
- **Correção:** a checagem antiga não era atômica — dois cadastros simultâneos com
  o mesmo nome passavam os dois. Agora a atomicidade vem de `allow update: if false`
  nas Rules: um `set()` sobre slug tomado é avaliado como update e negado. Coberto
  por teste em `test/firestore_rules/firestore.rules.test.js`.
- **Correção:** editar o perfil não checava unicidade nenhuma; dava para assumir o
  nome de outra conta contornando a validação do cadastro.
- **Efeito colateral desejado:** o slug ignora acentos e pontuação, então "José
  Silva" e "Jose Silva" disputam o mesmo documento. Em app de denúncia, nomes
  visualmente confundíveis são vetor de personificação.
- **Backfill obrigatório** antes de publicar:
  `node scripts/backfill_nomes_reservados.mjs --projeto ecojp-8b952 --aplicar`.
  Sem ele, contas antigas ficam sem reserva e alguém pode tomar o nome delas.

**Lacuna que fica:** nada prova que o slug reservado corresponde ao campo `nome` do
perfil, porque no cadastro a reserva precede a criação do perfil. Uma conta pode
reservar um nome que não usa. Fechar isso exige trigger em `usuarios/{uid}` — é o
primeiro caso de uso concreto da camada de Cloud Functions decidida aqui.

## Quando revisitar esta decisão

Esta decisão não é permanente. Gatilhos concretos para reabrir:

1. **Relatório relacional ao vivo** que o export para BigQuery não atenda — JOIN de
   várias coleções com agregação renderizada na tela, não em dashboard.
2. **Consulta geoespacial por raio** em que geohash com bounding box se mostre
   insuficiente na prática. Aí o PostGIS ganha de verdade.
3. **Composição do time**: se quem mantém o projeto for muito mais forte em SQL do
   que em modelagem de documento. É argumento legítimo, ainda que não técnico.

Nenhum dos três se aplica em 2026-09-10.
