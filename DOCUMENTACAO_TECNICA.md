# EcoJP — Documentação Técnica de Produto

**Aplicativo colaborativo de zeladoria urbana para João Pessoa (PB)**
Flutter · Firebase · Cloudinary · Gemini (Firebase AI Logic)

| Métrica | Valor |
|---|---|
| Arquivos Dart | 70 (`lib/`) |
| Linhas de código Dart | ~20.500 |
| Camada de serviços | 13 services |
| Modelos de domínio | 7 models |
| Páginas / telas | 30 arquivos em `lib/pages` (12 raiz + 4 perfil + 2 legal + módulo de mapa) |
| Testes automatizados | 58 casos Dart + 15 casos de Firestore Rules |
| Município-alvo | João Pessoa (`municipioId: 'joao-pessoa'`) |
| Nota geral de arquitetura | **7,5 / 10** |

> Este documento é a entrega técnica oficial do projeto. Cada afirmação é
> ancorada em arquivos e trechos reais do código-fonte. Referências no formato
> `arquivo.dart:linha` apontam para a implementação correspondente.

---

## Sumário

1. [Engenharia de Requisitos](#01--engenharia-de-requisitos)
2. [UX / UI](#02--ux--ui)
3. [Arquitetura do Sistema](#03--arquitetura-do-sistema)
4. [Modelagem de Dados](#04--modelagem-de-dados)
5. [Integração Firebase](#05--integração-firebase)
6. [Qualidade e Evolução](#06--qualidade-e-evolução)

---

## 01 · Engenharia de Requisitos

### 1.1 Contexto e domínio

O EcoJP é uma plataforma de **zeladoria urbana colaborativa** para o município
de João Pessoa. O cidadão registra ocorrências no espaço público — problemas de
**saneamento**, **saúde pública** e **infraestrutura urbana** — e o poder
público (perfil *autoridade*) tria, verifica e conduz o ciclo de resolução.

A partição por município já é decisão de projeto, não intenção: cada denúncia
nasce carimbada com `municipioId: 'joao-pessoa'`
([ocorrencia_model.dart:124](lib/models/ocorrencia_model.dart#L124)), evitando
migração retroativa quando o app expandir para outros municípios da Paraíba.

### 1.2 Taxonomia de ocorrências (cenário João Pessoa)

As categorias não são genéricas: mapeiam diretamente as competências de
zeladoria de uma prefeitura litorânea do Nordeste, com forte incidência de
chuvas concentradas e ocupação irregular. Definidas no enum
[`OccurrenceType`](lib/models/occurrence_types.dart#L12):

| Categoria | Domínio de zeladoria | Órgão típico em JP |
|---|---|---|
| **Lixo** | Saneamento / limpeza urbana | EMLUR |
| **Esgoto** | Saneamento / saúde pública | CAGEPA / SEINFRA |
| **Enchentes** | Drenagem / defesa civil | SEINFRA / Defesa Civil |
| **Buraco** | Infraestrutura viária | SEINFRA |
| **Queimada** | Meio ambiente / saúde | SEMAM / Bombeiros |
| **Árvores caídas** | Arborização / risco | SEMAM |
| **Falta iluminação** | Infraestrutura / segurança | Iluminação pública |
| **Outros** | Catch-all triável | — |

Cada categoria carrega metadados de apresentação (ícone, cor, matiz de marcador
no mapa) na mesma fonte de verdade — ver
[`markerHue`](lib/models/occurrence_types.dart#L89), que traduz a categoria para
a paleta limitada de *hues* do Google Maps.

### 1.3 Personas e requisitos funcionais

**Persona 1 — Cidadão (Marina).** Quer reportar um problema em ~30s e
acompanhar a resolução.
**Persona 2 — Autoridade (Carlos, fiscal).** Precisa triar, verificar em campo
e conduzir o ciclo oficial, com trilha de auditoria.
**Persona 3 — Consumidor de dados (MPPB).** Quer estatísticas agregadas
confiáveis (funil de triagem, tempos médios).

Requisitos funcionais implementados, com evidência no código:

| RF | Requisito | Evidência |
|---|---|---|
| RF01 | Registro de denúncia com foto/vídeo, GPS e categoria | [form_ocorrencia_page.dart](lib/pages/form_ocorrencia_page.dart) (1726 linhas) |
| RF02 | Sugestão de categoria por IA | [classificacao_ia_service.dart](lib/services/classificacao_ia_service.dart) |
| RF03 | Denúncia anônima com proteção de identidade | [ocorrencia_model.dart:104-108](lib/models/ocorrencia_model.dart#L104) |
| RF04 | Feed com reações (like/dislike) e comentários | [ocorrencia_service.dart:545](lib/services/ocorrencia_service.dart#L545) |
| RF05 | Mapa com clustering, heatmap e busca por bairro | [lib/pages/mapPage/](lib/pages/mapPage/) |
| RF06 | Ciclo de vida oficial (triagem → resolução) | [ocorrencia_model.dart:43-52](lib/models/ocorrencia_model.dart#L43) |
| RF07 | Moderação de conteúdo abusivo | [moderacao_service.dart](lib/services/moderacao_service.dart), [fila_moderacao_page.dart](lib/pages/fila_moderacao_page.dart) |
| RF08 | Estatísticas / painel administrativo | [estatisticas_page.dart](lib/pages/estatisticas_page.dart) (1483 linhas) |
| RF09 | Relatório PDF exportável | [relatorio_service.dart](lib/services/relatorio_service.dart) |
| RF10 | Notificações in-app | [notificacao_service.dart](lib/services/notificacao_service.dart) |
| RF11 | Consentimento LGPD comprovável | [consent_service.dart](lib/services/consent_service.dart) |
| RF12 | Verificação de e-mail obrigatória | [auth_service.dart:166](lib/services/auth_service.dart#L166) |

### 1.4 Regras de negócio no servidor

As regras de negócio críticas não vivem só no cliente — são reaplicadas nas
Firestore Rules (ver [Seção 5](#05--integração-firebase)). Exemplos:
o status inicial de toda denúncia **precisa** ser `'Pendente'`, contadores
começam zerados, e a `dataCriacao` é forçada a `request.time` do servidor
(impossível forjar data). Isso caracteriza validação *defense-in-depth*.

### 1.5 Lacunas de requisitos (backlog priorizado)

| Item | Impacto | Depende de |
|---|---|---|
| Push notification (retorno do cidadão) | Retenção | Cloud Functions + Blaze |
| Detecção de duplicidade (mesma ocorrência N vezes) | Qualidade de dados | Cloud Functions |
| SLA/prazos por categoria | Metas de tempo p/ autoridade | Modelagem |
| Concessão de papel *autoridade* via app | Escala institucional | Cloud Functions |

---

## 02 · UX / UI

### 2.1 Fluxo de registro — o núcleo do produto

O formulário de denúncia ([form_ocorrencia_page.dart](lib/pages/form_ocorrencia_page.dart),
o maior arquivo do projeto com 1726 linhas) implementa um fluxo em cascata que
reduz o atrito do cidadão:

```
Foto/vídeo → compressão local → IA sugere categoria → GPS/endereço
   → confirmação explícita → upload (Cloudinary) + gravação (Firestore)
```

Pontos de UX de nível de produto:

- **Compressão antes do upload** — imagens são reduzidas (qualidade 80, ~1600px)
  no dispositivo, economizando banda do cidadão (relevante em rede móvel).
- **IA como assistente, nunca decisor** — a sugestão de categoria é
  pré-selecionada, mas o usuário pode trocar antes de enviar. O comentário no
  código é explícito: *"humano decide por último"*
  ([classificacao_ia_service.dart:11](lib/services/classificacao_ia_service.dart#L11)).
- **Confirmação antes do envio** — evita denúncias acidentais.
- **Feedback de progresso rico** — o upload reporta estado (`_uploadAtual`,
  `_uploadTotal`) e mensagens de status.

### 2.2 Componentização

O feed é construído sobre um widget reutilizável central,
[`OccurrenceCard`](lib/widgets/occurrence_card.dart) (1338 linhas), compartilhado
entre home, perfil e perfil público. Ele encapsula: carrossel de imagens,
player de vídeo, faixa de status oficial, barra de ações e preview de
comentários. Widgets auxiliares reutilizáveis:

| Widget | Responsabilidade |
|---|---|
| [`OccurrenceCommentsSheet`](lib/widgets/occurrence_comments_sheet.dart) | Bottom sheet de comentários (com respostas via `parentId`) |
| [`OcorrenciaActions`](lib/widgets/ocorrencia_actions.dart) | Menu do dono (editar / excluir) |
| [`ReportContentSheet`](lib/widgets/report_content_sheet.dart) | Denúncia de abuso |
| [`FeedStates`](lib/widgets/feed_states.dart) | Estados de carregamento / vazio / erro |

### 2.3 Sistema de design

O tema é centralizado em [`AppTheme`](lib/theme/app_theme.dart) com Material 3
(`useMaterial3: true`) e uma paleta nomeada em `AppColors` (ink, muted, primary,
danger, etc.). A padronização foi reforçada nesta rodada: **37 cores hardcoded
duplicadas** (`Color(0xFF...)` idênticos às constantes) foram unificadas em 13
arquivos, restando apenas as 11 definições canônicas em `app_theme.dart`.

### 2.4 Acessibilidade

O app aplica `Semantics` nos elementos interativos-chave. Botões de reação já
expõem rótulo e estado para leitores de tela
([occurrence_card.dart](lib/widgets/occurrence_card.dart), `_ActionButton` com
`Semantics(button: true, label: ..., selected: active)`), e todas as 5 imagens
de rede (`Image.network`) receberam `semanticLabel` descritivo — sem isso, o
leitor de tela anunciaria apenas "imagem". Botões só-ícone do formulário
(adicionar/remover foto) foram envolvidos em `Semantics` com rótulo.

**Backlog de UX:** onboarding funcional (hoje só tela de marketing), adaptação
para tablet/desktop, e preview de vídeo no formulário.

---

## 03 · Arquitetura do Sistema

### 3.1 Camadas

O projeto adota uma arquitetura em camadas pragmática, adequada ao porte:

```
┌─────────────────────────────────────────────────────┐
│  Presentation   pages/ (28)  +  widgets/ (5)         │
│                 mapPage/ (controller + widgets)       │
├─────────────────────────────────────────────────────┤
│  Domain         models/ (7) — Entity + DTO + Mapper   │
│                 occurrence_types.dart (enums+extensões)│
├─────────────────────────────────────────────────────┤
│  Service        services/ (13) — regra de negócio     │
│                 + acesso a dados                       │
├─────────────────────────────────────────────────────┤
│  Infra          Firebase SDK · Cloudinary · Gemini    │
│                 Geolocator · Google Maps               │
└─────────────────────────────────────────────────────┘
```

**Padrão de acesso a dados.** Cada service encapsula uma responsabilidade e
expõe `Stream`/`Future` tipados para a UI. Exemplo típico — o
[`OcorrenciaService`](lib/services/ocorrencia_service.dart) (747 linhas)
concentra CRUD de ocorrências, comentários, reações e moderação, sempre
convertendo `DocumentSnapshot` → `OcorrenciaModel` na fronteira.

**Instância compartilhada.** Para evitar recriar services em cada widget, o
padrão adotado é um singleton opcional (`static final instance = ...`), mantendo
o construtor público disponível para testes
([ocorrencia_service.dart:19](lib/services/ocorrencia_service.dart#L19)).

### 3.2 Concorrência e reatividade

A camada de serviço demonstra domínio de programação reativa não-trivial. O
método [`listarFeedComFixadas`](lib/services/ocorrencia_service.dart#L90) combina
**dois streams do Firestore** (recentes + fixadas) num único `StreamController`
com deduplicação por id e reordenação — resolvendo o problema de "posts fixados
pela autoridade sempre no topo" sem uma query composta cara.

Correção de consistência via **transação**: `toggleLike`/`toggleDislike`
([ocorrencia_service.dart:545](lib/services/ocorrencia_service.dart#L545)) rodam
em `runTransaction`, garantindo que like e dislike sejam mutuamente exclusivos
mesmo sob concorrência, com contadores sempre derivados das listas
(`likes == likedBy.length`).

### 3.3 Resiliência — cascata de geocoding

O [`LocationService`](lib/services/geolocation/geolocation_service.dart) exibe
maturidade de engenharia acima do esperado para um MVP:

- **Cache em memória por bairro** — coordenadas já resolvidas não são
  recalculadas na sessão ([geolocation_service.dart:17](lib/services/geolocation/geolocation_service.dart#L17)).
- **Bounding box de João Pessoa** — descarta resultados de cidades homônimas em
  outros estados, evitando o mapa "pular" para o lugar errado
  ([geolocation_service.dart:22](lib/services/geolocation/geolocation_service.dart#L22)).
- **Degradação graciosa na web** — o plugin `geocoding` não existe no navegador;
  o código usa `?.` e retorna `null` em vez de quebrar.

### 3.4 Nota de arquitetura — **7,5 / 10** (justificada)

**A favor (o que puxa a nota para cima):**
- Separação de camadas coerente e consistente.
- Reatividade correta (streams combinados, transações onde há concorrência).
- Segurança *defense-in-depth* (cliente + Firestore Rules).
- Resiliência real na integração externa (geocoding, App Check).

**Contra (o que impede nota maior):**
- **Ausência de injeção de dependência** — services são instanciados
  diretamente (~43 pontos), o que limita a testabilidade de widgets isoladamente.
- **Arquivos extensos** — 4 arquivos acima de 1000 linhas
  (`form_ocorrencia_page` 1726, `detalhe_ocorrencia_page` 1516,
  `estatisticas_page` 1483, `occurrence_card` 1338) misturam UI e lógica.
- **Múltiplos padrões de tratamento de erro** coexistindo (try/catch com
  `debugPrint` + rethrow, `AuthResult`, silencioso).

> **Decisão consciente:** migrar para Riverpod/Bloc/GoRouter ou reestruturar por
> *feature* **não** é recomendado no porte atual — o custo de refatoração supera
> o retorno. A modelagem "Entity+DTO+Mapper numa classe" é o padrão correto
> aqui, pois não há múltiplas fontes de dados (só Firestore).

---

## 04 · Modelagem de Dados

### 4.1 Modelos de domínio

Sete modelos em [lib/models/](lib/models/). O central é
[`OcorrenciaModel`](lib/models/ocorrencia_model.dart), com ~30 campos que cobrem
todo o ciclo de vida:

| Bloco de campos | Propósito |
|---|---|
| `titulo`, `descricao`, `localizacao`, `latitude/longitude`, `tipoLixo` | Conteúdo da denúncia |
| `imagemUrl`, `imagensUrls`, `videoUrl` | Mídia (Cloudinary) |
| `anonima`, `usuarioId`, `usuarioNome`, `usuarioFotoUrl` | Autoria + proteção de identidade |
| `likedBy`, `dislikedBy`, `likes`, `dislikes`, `comments` | Engajamento (listas + contadores derivados) |
| `verificada`, `verificadaPorNome`, `verificadaEm` | Verificação oficial (auditoria) |
| `statusOficial`, `encaminhadaEm`, `resolvidaEm`, `fixada` | Ciclo de vida oficial |
| `oculto` | Moderação de abuso |
| `municipioId` | Partição multi-município (futuro) |

### 4.2 Serialização e a fronteira de dados

O `toMap()`/`fromMap()` é o ponto onde as regras de negócio de dados são
aplicadas antes de tocar o Firestore. Trecho crítico de **proteção do
denunciante anônimo** ([ocorrencia_model.dart:104-124](lib/models/ocorrencia_model.dart#L104)):

```dart
// Denúncia anônima: o UID real não vai no documento público.
'usuarioId': anonima ? null : usuarioId,
...
'likes': 0, 'dislikes': 0, 'comments': 0,   // contadores sempre zerados na criação
'likedBy': [], 'dislikedBy': [],
'municipioId': 'joao-pessoa',                // partição já na origem
```

O UID real do denunciante anônimo **nunca** vai ao documento público — vive
apenas numa subcoleção privada `ocorrencias/{id}/dono/info`, legível só pelo
próprio dono ou pela autoridade. Isso impede correlacionar denúncias anônimas
pelo autor (mitigação de risco de privacidade, "S2").

### 4.3 Ciclo de vida oficial (máquina de estados)

O `statusOficial` codifica uma máquina de estados documentada no próprio modelo
([ocorrencia_model.dart:43-52](lib/models/ocorrencia_model.dart#L43)):

```
                 ┌──────────────► nao_confirmada  (foi ao local, não existia)
                 │
Pendente ──► em_analise ──► [verificada=true] ──► encaminhada ──► resolvida
(null)                       = "confirmada"        (+encaminhadaEm)  (+resolvidaEm)
```

Estados pré-confirmação (`em_analise`, `nao_confirmada`) exigem
`verificada == false`; estados pós-confirmação (`encaminhada`, `resolvida`)
exigem `verificada == true` e gravam carimbo de tempo — formando trilha de
auditoria imutável.

### 4.4 Fluxos de informação

```
CIDADÃO                          FIRESTORE                    AUTORIDADE
   │  cadastrarOcorrencia()          │                            │
   ├────────────────────────────────►│ ocorrencias/{id}           │
   │                                 │  (status=Pendente)         │
   │                                 │◄───────────────────────────┤ listarParaVerificacao()
   │                                 │  update statusOficial      │
   │  notificacao ◄──────────────────┤  historico/{ev} (append)   │
   │                                 │                            │
```

Toda mudança de status gera um evento **append-only** em
`ocorrencias/{id}/historico`, gravado em batch atômico junto com a atualização
([ocorrencia_service.dart:338-352](lib/services/ocorrencia_service.dart#L338)).

---

## 05 · Integração Firebase

### 5.1 Serviços em uso

| Serviço | Status | Uso |
|---|---|---|
| Authentication | ✅ | E-mail/senha + Google, verificação de e-mail |
| Cloud Firestore | ✅ | Banco principal |
| App Check | ✅ | Play Integrity (Android) / App Attest (iOS) |
| Firebase AI Logic (Gemini) | ✅ | Sugestão de categoria |
| Analytics | ✅ | Eventos de uso |
| Crashlytics | ✅ | Estabilidade |
| **Storage** | ❌ | Substituído por **Cloudinary** (decisão de custo) |
| Cloud Messaging / Functions | ⏳ | Pendente do plano Blaze |

**Decisão de arquitetura — Cloudinary sobre Storage.** As mídias são hospedadas
no Cloudinary, não no Firebase Storage. As Firestore Rules validam que toda URL
de imagem aponta para o *cloud name* do projeto via regex
(`isCloudinaryImageUrl`), impedindo injeção de URLs externas.

### 5.2 Autenticação

O [`AuthService`](lib/services/auth_service.dart) (338 linhas) cobre o ciclo
completo: cadastro, login e-mail/senha, login Google (com caminhos distintos
para web `signInWithPopup` e mobile `google_sign_in`), recuperação de senha,
verificação de e-mail, reautenticação e **exclusão de conta (LGPD art. 18)**.

Detalhe de segurança: só contas **e-mail/senha** precisam confirmar e-mail;
contas federadas (Google) já chegam verificadas — a distinção é feita
inspecionando `providerData`
([auth_service.dart:166-170](lib/services/auth_service.dart#L166)).

Toda mensagem de erro do `FirebaseAuthException` é traduzida para pt-BR
amigável (mapas `_mensagemLogin`, `_mensagemCadastro`, `_mensagemRecuperacao`),
evitando vazar códigos técnicos ao usuário.

### 5.3 Modelagem das coleções do Firestore

```
ocorrencias/{id}                        ← documento principal (~30 campos)
  ├── comentarios/{id}                  ← respostas via parentId (não aninhamento)
  ├── historico/{id}                    ← append-only, auditoria imutável
  └── dono/info                         ← UID real de denúncia anônima (privado)

usuarios/{uid}                          ← perfil (= auth uid)
  ├── favoritos/{ocorrenciaId}
  ├── seguindo/{alvoUid}, seguidores/{seguidorUid}   ← grafo social
  └── minhas_denuncias_anonimas/{id}    ← ponteiros p/ "Minhas denúncias"

notificacoes/{uid}/items/{id}           ← notificações in-app
denuncias_moderacao/{id}                ← denúncias de abuso
roles/{uid}                             ← papel (só leitura pelo app)
consentimentos/{uid}                    ← registro LGPD comprovável
```

### 5.4 Regras de segurança (defense-in-depth)

As [firestore.rules](firestore.rules) (624 linhas) são o ativo de segurança mais
robusto do projeto. Elas não confiam no cliente — revalidam **estrutura, tipo,
tamanho e regra de negócio** de cada operação. Funções-chave:

- `emailVerificado()` — só quem confirmou e-mail cria conteúdo.
- `isAutoridade()` — checa `roles/{uid}` via `get()`; **escrita em `roles/` é
  sempre negada** (`allow write: if false`), então o papel só pode ser concedido
  pelo Console Admin, nunca pelo app.
- `isValidOcorrencia(data)` — valida `hasAll`/`hasOnly` das chaves, faixas de
  coordenada, categoria dentro do enum, `status == 'Pendente'`,
  `dataCriacao == request.time`, e a regra de anonimato (se `anonima`, então
  `usuarioId == null` e sem nome/foto).
- `isValidReactionUpdate()` — permite ao usuário **apenas** adicionar/remover o
  próprio UID nas listas de reação, com os 6 casos possíveis (add/remove
  like/dislike, switch) explicitamente enumerados.
- `isValidStatusOficialUpdate()` — só autoridade avança o ciclo, com as
  pré-condições de `verificada` por estado.

Exemplo — proteção da coordenada (0,0) e do bounding box de validação:

```
function isValidCoordinate(lat, lon) {
  return lat is number && lon is number
    && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    && !(lat == 0 && lon == 0);   // rejeita coordenada nula (bug comum de GPS)
}
```

### 5.5 App Check e segredos

O App Check é ativado com providers de produção e *guarda* de debug
([main.dart:29-42](lib/main.dart#L29)): `AndroidPlayIntegrityProvider` /
`AppleAppAttestProvider` em release, providers de debug **somente** sob
`kDebugMode`. A chamada ao Gemini é protegida pelo App Check — **nenhuma chave de
API fica no app**, e a inferência só funciona vinda do app real instalado
([classificacao_ia_service.dart:8-9](lib/services/classificacao_ia_service.dart#L8)).

---

## 06 · Qualidade e Evolução

### 6.1 Estratégia de testes

O projeto tem **duas suítes complementares**:

**a) Testes unitários Dart — 58 casos** em 8 arquivos ([test/](test/)),
cobrindo models, enums, utils e o algoritmo de zonas mais afetadas:

```
test/models/          ocorrencia_model, comentario/denuncia_moderacao, occurrence_types, rota_coleta
test/pages/           calc_mostaffectedzones (algoritmo de agregação do mapa)
test/services/        cloudinary_service
test/utils/           tempo_relativo
```

**b) Testes de Firestore Rules — 15 casos** ([test/firestore_rules/](test/firestore_rules/)),
executados contra o **emulador do Firestore** com `@firebase/rules-unit-testing`.
Esta suíte valida a camada de segurança de ponta a ponta — o ativo mais crítico:

| Cenário testado | Garante |
|---|---|
| Leitura exige autenticação | Nada é público sem login |
| Criação exige e-mail verificado | Barreira anti-spam de base |
| `usuarioId != uid` é rejeitado | Impossível forjar autoria |
| Anônima com UID no doc público falha | Proteção de identidade (S2) |
| Coordenada (0,0) / imagem não-Cloudinary falha | Integridade de dados |
| Autoconceder papel `autoridade` falha | Escalonamento de privilégio |
| Só autoridade oculta / muda status | Autorização de moderação |
| Usuário não edita perfil alheio | Isolamento de dados |

Execução: `cd test/firestore_rules && npm test` (sobe o emulador, roda Jest,
derruba o emulador — requer Java/JVM). Nota de implementação: as regras exigem
`dataCriacao == request.time`, então os testes usam `serverTimestamp()`, não
`new Date()`.

**Cobertura em aberto:** 10 dos 13 services sem teste de lógica de negócio;
zero testes de widget e de integração/E2E. São os próximos passos de maturidade.

### 6.2 DevOps / CI-CD

O pipeline [.github/workflows/ci.yml](.github/workflows/ci.yml) roda em cada
`push`/`pull_request` na `main`:

```yaml
1. Checkout + Setup Flutter (channel stable, cache)
2. flutter pub get
3. Injeta MAPS_API_KEY via secret (não versionada)
4. Gera firebase_options.dart de CI (placeholders — não expõe projeto real)
5. dart format --set-exit-if-changed  (não-bloqueante, warning)
6. flutter analyze                     (bloqueante)
7. flutter test                        (bloqueante)
```

Destaques de maturidade: **segredos fora do repositório** (a chave do Maps entra
por `secrets.MAPS_API_KEY`), e um `firebase_options.dart` sintético de CI que
permite compilar/testar sem expor a configuração real do Firebase.

**Gaps de DevOps:** ausência de ambiente de **staging** (hoje testes locais
atingem produção), formatação não-bloqueante (inconsistente com o rigor de
`analyze`/`test`), e sem build/CD automatizado de APK. A suíte de Firestore
Rules ainda não está integrada ao `ci.yml` — é o próximo passo natural.

### 6.3 Roadmap de escalabilidade

A arquitetura suporta o crescimento em patamares bem definidos:

| Usuários | Ação necessária |
|---|---|
| 10 – 1.000 | **Nenhuma mudança** — a stack atual aguenta |
| ~1.000 | Monitorar teto de agregação (`tetoAgregado = 500`, [ocorrencia_service.dart:15](lib/services/ocorrencia_service.dart#L15)) |
| ~10.000 | **Cloud Functions obrigatórias** (Blaze): push, rate limit server-side, agregação, `municipioId` operacional |
| ~100.000 | Sharded counters, cache de feed, particionamento geográfico |
| ~1.000.000 | Backend híbrido, BigQuery, multi-region (exercício teórico) |

**A decisão estrutural única represada** é a adoção de **Cloud Functions + plano
Blaze**. Ela desbloqueia, de uma vez: push notification, rate limiting robusto
(hoje há um mitigador client-side em [rate_limiter.dart](lib/services/rate_limiter.dart)),
agregação server-side de estatísticas, detecção de duplicidade e concessão de
papéis pela UI. Enquanto isso, mitigadores client-side e o tier gratuito
(Spark) sustentam o produto até a faixa de 1.000 usuários.

**Sobre trocar de backend:** a recomendação é **não migrar** do Firebase agora —
todo gap tem solução dentro do próprio ecossistema. Se um dia for necessário, o
caminho de menor atrito é **NestJS** (TypeScript compartilha DNA com Dart e
permite migração incremental, mantendo o Firestore como banco).

---

### Conclusão

O EcoJP transcende o rótulo de "projeto acadêmico": entrega um fluxo de
zeladoria urbana completo, segurança *defense-in-depth* validada por testes
automatizados, integração de IA responsável (humano no controle) e uma trilha de
auditoria institucional. As lacunas restantes são conhecidas, priorizadas e, em
sua maioria, convergem para uma única decisão de infraestrutura (Blaze) — não
para dívida arquitetural estrutural.

---

*Documento gerado a partir da análise do código-fonte real (70 arquivos Dart,
~20.500 linhas). Última atualização: 12 de julho de 2026.*

---

# APÊNDICE — FASE 17: PRODUCTION READINESS & GO-LIVE

Este documento é complementado pelo **PRODUCTION_READINESS_AUDIT.md**.

## Contexto

EcoJP foi desenvolvido com arquitetura sólida, documentada e validada. O objetivo agora é transformar este projeto em um **produto pronto para produção (Production Ready)**, apto para publicação na Google Play Store, Apple App Store e Web.

## Função do Tech Lead

O Staff Software Engineer responsável atua como **líder técnico** no:
- Planejamento de cada etapa
- Revisão e aprovação de mudanças
- Condução de refatorações
- Decisões arquiteturais
- Aprovação final de deploy em produção

## Regras de Conduta

1. **Nunca implemente sem planejamento** — explique objetivo, impacto, dependências, riscos, arquivos afetados e estratégia
2. **Sempre siga Clean Code, SOLID, Clean Architecture e Flutter Lints**
3. **Sempre utilize boas práticas do Firebase**
4. **Nunca gere código duplicado** — proponha refatorações quando necessário
5. **Trabalhe por etapas** — una por vez, sempre aguardando aprovação antes de continuar

## Plano de Execução

### ETAPA 17.1 — AUDITORIA COMPLETA ✅
Realizado em: **12 de julho de 2026**
Relatório: **PRODUCTION_READINESS_AUDIT.md**

**Verificações:**
- Estrutura e organização do código
- Acoplamento e responsabilidades
- Código morto e duplicação
- Dependências desnecessárias
- Widgets e services gigantes
- Performance e memória
- Escalabilidade

**Status:** ⚠️ Parcialmente Pronto — Necessárias ações críticas antes de Go-Live

---

### ETAPA 17.2 — REVISÃO DE MÓDULOS ✅

Realizada em: **13 de julho de 2026**
Relatório completo: **PRODUCTION_READINESS_MODULOS.md**

| Módulo | Nota | Prioridade |
|---|---|---|
| Auth | 8/10 | Baixa |
| Home / Feed | 6/10 | **Alta** |
| Mapa | 8/10 | Baixa |
| Denúncias (Ocorrências) | 7/10 | **Alta** |
| Perfil | 6/10 | Média |
| Admin (Fila Verificação + Moderação) | 6.5/10 | Média |
| Configurações | 7.5/10 | **Alta** (compliance) |
| Notificações | 7.5/10 | Baixa |
| Favoritos | 7/10 | Baixa |
| Estatísticas | 6.5/10 | Média |

**Média geral dos módulos: 7.05/10**

**Achados transversais principais** (detalhes no relatório completo):
1. Migração Riverpod pela metade — providers de denúncias existem mas não são consumidos em nenhuma page
2. Duplicação de lógica de resolução de autor entre Home e Detalhe de Ocorrência
3. Duas violações diretas de camada (Firestore chamado fora de service/repository)
4. Padrão StreamBuilder aninhado repetido em Home e Perfil
5. Ausência de `.limit()` em 3 queries administrativas (Fila Verificação, Moderação, Favoritos)
6. Verificação de papel (`isAutoridade`) repetida de forma independente em 5+ telas

---

### ETAPA 17.3 — REFATORAÇÃO
- Código duplicado
- Código morto
- Violações SOLID
- Widgets/services gigantes
- Baixa legibilidade

---

### ETAPA 17.4 — PERFORMANCE
- Rebuilds
- Memória
- Queries Firestore
- Cache
- Imagens
- Listas e paginação
- Lazy loading
- Índices
- Uploads/downloads

---

### ETAPA 17.5 — SEGURANÇA
- Firestore Rules
- Storage Rules
- Authentication
- Autorização
- App Check
- LGPD
- Permissões
- Validações
- Rate Limit
- Ataques comuns

---

### ETAPA 17.6 — TESTES
Objetivo: 90% de cobertura em regras críticas
- Testes unitários para lógica de negócio
- Testes de widgets essenciais
- Testes de integração
- Testes End-to-End

---

### ETAPA 17.7 — UX/UI
- Usabilidade
- Acessibilidade
- Navegação
- Responsividade
- Consistência visual
- Animações
- Feedback visual
- Mensagens de erro
- Estados vazios
- Estados de carregamento

---

### ETAPA 17.8 — PAINEL ADMINISTRATIVO
- Dashboard
- Filtros
- Permissões
- Estatísticas
- Exportação
- Auditoria
- Gestão de usuários
- Gestão de denúncias

---

### ETAPA 17.9 — DEVOPS
- GitHub Actions CI/CD
- Build Android (APK)
- Build iOS (IPA)
- Build Web
- Flutter Analyze
- Flutter Test
- Deploy Firebase
- Versionamento (SemVer)
- Release Notes

---

### ETAPA 17.10 — PUBLICAÇÃO
- Google Play Store
- Apple App Store ⏸️ **PAUSADO** (ver nota abaixo)
- Firebase Hosting (Web)
- Ícones e splash screen
- Screenshots
- Descrições
- Política de privacidade
- Termos de uso
- Permissões
- Assinaturas digitais
- Certificados
- Ambientes de produção

> ⏸️ **PENDENTE DE DECISÃO DO USUÁRIO — retomar quando disponível:**
>
> | Item | Bloqueia | Status | Custo |
> |---|---|---|---|
> | **Conta Apple Developer** | Build IPA, TestFlight, App Store | Não adquirida | US$ 99/ano |
> | **Firebase Blaze (pay-as-you-go)** | Cloud Functions → push notifications reais, detecção de duplicidade, rate limit server-side, agregação server-side de estatísticas | Não adquirido | Variável (tier gratuito generoso; só cobra acima dele) |
>
> **Enquanto isso:** todo o trabalho de Android + Web + refatoração + testes + CI/CD
> segue normalmente, pois não depende de nenhum dos dois. Quando o usuário
> obtiver o plano Blaze e/ou a conta Apple Developer, retomar exatamente a
> partir daqui: build iOS (17.9/17.10) e Cloud Functions (push notification,
> detecção de duplicidade, rate limit server-side — ver Seção 1.5 e 6.3 do
> corpo principal deste documento).

---

### ETAPA 17.11 — OBSERVABILIDADE
- Firebase Crashlytics
- Firebase Analytics
- Firebase Performance
- Logging
- Monitoramento
- Dashboards
- Alertas
- KPIs

---

### ETAPA 17.12 — CHECKLIST FINAL
Relatório contendo:
- Pontos fortes
- Pontos fracos
- Débitos técnicos
- Bugs encontrados
- Melhorias implementadas
- Cobertura de testes
- Performance
- Segurança
- Custos Firebase estimados
- Escalabilidade
- Plano de manutenção
- Roadmap v2.0
- Roadmap v3.0
- Nota final (0–10)
- Índice de maturidade (0–100%)
- Checklist de Go-Live

---

## Status Atual

**ETAPA 17.1 — ✅ Concluída**
- Auditoria completa realizada
- Relatório disponível em: `PRODUCTION_READINESS_AUDIT.md`

**ETAPA 17.2 — ✅ Concluída**
- Revisão de 10 módulos realizada com leitura direta do código
- Relatório disponível em: `PRODUCTION_READINESS_MODULOS.md`
- Nota média dos módulos: 7.05/10

**Ações Críticas Identificadas (ETAPA 17.1):**
1. 🔴 Refatorar 4 widgets/services > 1000 linhas
2. 🔴 Adicionar testes de widget
3. 🔴 Integrar Firestore Rules tests ao CI/CD
4. 🔴 Rate limiting server-side
5. 🔴 Build APK automático no CI

**Ações Adicionais Identificadas (ETAPA 17.2):**
6. 🔴 2 violações diretas de camada (Firestore fora de service) + duplicação de resolução de autor
7. 🔴 Catch silencioso em exclusão de conta (LGPD) sem log/retry
8. ⚠️ `.limit()` ausente em 3 queries administrativas (Fila Verificação, Moderação, Favoritos)
9. ⚠️ Decidir destino dos providers Riverpod não utilizados (remover ou migrar de fato)
10. ⚠️ Verificação de papel (`isAutoridade`) duplicada em 5+ telas — candidato a provider único

**Próxima:** ETAPA 17.3 — Refatoração (aguardando aprovação)
