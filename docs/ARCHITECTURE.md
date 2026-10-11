# Arquitetura — EcoJP

> Como o sistema é montado. Requisitos em [PRD.md](PRD.md); convenções em [RULES.md](RULES.md).

**Atualizado em:** 02/10/2026

---

## 1. Visão geral

```
┌──────────────────────────┐
│  App Flutter (Android/iOS)│
│  Riverpod + go_router     │
└──────┬─────────┬──────────┘
       │         │ upload unsigned (preset Eco_JP)
       │         ▼
       │   ┌───────────┐
       │   │ Cloudinary│  fotos e vídeos
       │   └───────────┘
       │ SDK Firebase (com App Check)
       ▼
┌────────────────────────────────────────────┐
│ Firebase                                    │
│  Auth (e-mail/senha, Google)                │
│  Firestore (dados + Rules = camada servidor)│
│  Crashlytics · Analytics · App Check        │
└────────────────────────────────────────────┘
       ▲
       │ Google Maps SDK / Geocoding
```

Não há backend próprio. **As Firestore Rules são a camada de servidor**: validam cada
campo, dono, papel, geofence, intervalos e eventos de auditoria. Uma pasta `functions/`
em TypeScript está planejada para o que as Rules não resolvem (apagar mídia na exclusão
de conta, contadores agregados, notificações push).

Decisão de stack (ADR 0001, 10/09/2026, no histórico do git): fica no Firebase. O argumento
decisivo é o suporte offline; o Blaze não tem piso de cobrança, e a conta alta vem do
padrão de leitura, não do fornecedor.

## 2. Stack

| Camada | Tecnologia |
|---|---|
| UI | Flutter 3.47 (Material 3), Google Fonts (Poppins + Inter) |
| Estado | `flutter_riverpod` 2.x |
| Navegação | `go_router` 12 + deep link `ecojp://` (`app_links`) |
| Auth | `firebase_auth`, `google_sign_in` |
| Dados | `cloud_firestore` |
| Mídia | Cloudinary (upload unsigned), `image`, `video_player`, `cached_network_image` |
| Mapa | `google_maps_flutter`, `geolocator` |
| Relatórios | `pdf`, `printing` |
| Observabilidade | `firebase_crashlytics`, `firebase_analytics` |
| Segurança | `firebase_app_check` (Play Integrity / App Attest / reCAPTCHA v3) |

## 3. Organização do código (`lib/`)

```
lib/
├── main.dart                 # bootstrap: Firebase, App Check, Crashlytics, ProviderScope
├── firebase_options.dart     # config pública do Firebase (versionada de propósito)
├── core/
│   ├── router/               # app_router.dart (go_router + redirects), routes.dart (caminhos)
│   ├── theme/                # theme_mode_provider.dart (claro/escuro)
│   ├── deep_link.dart        # ecojp://ocorrencia/<id>, destino pendente até o login
│   ├── sessao_unica.dart     # derruba a sessão quando a conta entra em outro aparelho
│   └── connectivity_provider.dart
├── features/                 # providers Riverpod por domínio
│   ├── auth/providers/
│   └── denuncias/providers/
├── data/repositories/        # acesso ao Firestore (ocorrências, comentários)
├── models/                   # entidades + (de)serialização
├── services/                 # regras de negócio e integrações (auth, cloudinary, moderação…)
│   └── geolocation/          # GPS, geocoding, geofence do município, bairros
├── pages/                    # telas (uma pasta quando a tela tem controllers/widgets)
├── widgets/                  # componentes reutilizáveis (card, comentários, ações)
├── theme/app_theme.dart      # tokens de cor, tipografia, ThemeData
└── utils/                    # funções puras (texto, distância, privacidade de mídia…)
```

**Fluxo de dependência:** `pages/widgets → features (providers) → services/repositories → Firebase`.
Telas não falam com o Firestore direto; passam por repositório ou serviço.

## 4. Modelo de dados (Firestore)

| Coleção | Conteúdo | Quem escreve |
|---|---|---|
| `ocorrencias/{id}` | Denúncia: categoria, descrição, mídia, local, bairro, status oficial, reações, `oculto` | Autor (criação/edição antes da verificação); autoridade (status, selo, ocultar) |
| `ocorrencias/{id}/comentarios/{id}` | Comentários e respostas | Usuário verificado |
| `ocorrencias/{id}/historico/{id}` | Eventos de auditoria do status (imutáveis) | Autoridade |
| `ocorrencias/{id}/dono/info` | Dono real da denúncia anônima (privado) | Criado no mesmo batch da denúncia |
| `ocorrencias/{id}/compartilhamentos/{uid}` | Um compartilhamento por usuário | Usuário |
| `usuarios/{uid}` | Perfil público | Próprio usuário |
| `usuarios/{uid}/minhas_denuncias_anonimas` · `meta` · `seguindo` · `seguidores` | Dados auxiliares do perfil (`meta/sessao` guarda só o id da sessão ativa) | Próprio usuário / seguidor |
| `nomes_reservados/{slug}` | Unicidade atômica do nome público | Criação única (`update: false`) |
| `notificacoes/{uid}/items/{id}` | Notificações (ID determinístico) | Ligadas a ação real |
| `denuncias_moderacao/{id}` | Denúncias de conteúdo abusivo | Usuário; autoridade resolve |
| `roles/{uid}` | Papel de autoridade | Só pelo Console |
| `consentimentos/{uid}` | Versão e data do aceite da política | Próprio usuário |
| `{document=**}` | — | Negado por padrão |

Índices compostos em `firestore.indexes.json` (ex.: `oculto + dataCriacao`, grupo
`compartilhamentos.uid`).

## 5. Fluxos principais

**Autenticação** — `app_router.dart` redireciona: sem login → `/inicial`; e-mail não
verificado → `/verificacao-email`; sem consentimento da versão atual → `/consentimento`;
caso contrário → `/home` (shell com abas Feed, Mapa, Dados, Perfil).

**Sessão única** — cada login grava um id aleatório no aparelho e em
`usuarios/{uid}/meta/sessao` (`SessaoService`). O aparelho cujo id deixa de bater com o do
servidor é desconectado com aviso. Se a gravação falhar, o app segue sem a checagem.

**Nova denúncia** — `form_ocorrencia_page` → `LocationController` (GPS + geofence +
geocoding) e `MediaController` (seleção, remoção de EXIF, limites 8 MB/50 MB) → rate
limiter → upload Cloudinary → batch no Firestore (denúncia + `dono/info` se anônima).

**Ciclo oficial** — autoridade na `fila_verificacao_page` muda o status; as Rules exigem
um evento em `historico` no mesmo batch; `notificacao_service` avisa o autor.

**Moderação** — usuário denuncia conteúdo (`report_content_sheet`) → `denuncias_moderacao`
→ `fila_moderacao_page` → autoridade oculta (`oculto: true`). Conteúdo oculto só é
visível ao dono e à autoridade.

**LGPD** — `consent_service` grava o aceite; `relatorio_service` exporta o PDF;
`usuario_service.excluirTodosDados` reautentica e apaga em lotes.

## 6. Segurança

- Rules: validação por campo, dono, papel, `email_verified`, geofence de João Pessoa,
  intervalo mínimo entre reações, notificações e status ligados a ação real.
- App Check ativo no app; imposição no Console pendente do registro de `br.com.ecojp.app`.
- Nenhum segredo no repositório: `google-services.json`, `key.properties`,
  `local.properties` (chave do Maps) e `.env` estão no `.gitignore`.
- Release Android exige `android/key.properties` (ou `ECOJP_PERMITIR_RELEASE_DEBUG=true` só local).

## 7. Testes e CI

| Suíte | Onde | Como rodar |
|---|---|---|
| Unitários/widget Dart (~190) | `test/` | `flutter test` |
| Regras do Firestore (~100) | `test/firestore_rules/` | `npm test` (emulador) |
| Carga (k6) | `loadtest/` | ver `loadtest/README.md` |

GitHub Actions (`.github/workflows/ci.yml`): analyze → format (bloqueante) → testes Dart →
testes de regras → build. `release.yml` assina com secrets e versiona pela tag.

## 8. Implantação

Ordem obrigatória quando as regras mudam de forma incompatível:

1. Publicar o app novo e esperar a adoção.
2. `firebase deploy --only firestore:indexes`
3. Backfills (`npm run backfill:oculto`, `npm run backfill:nomes`) — dry run, depois `--aplicar`.
4. `firebase deploy --only firestore:rules`

## 9. Dívidas conhecidas de escala

- Reações em arrays dentro do doc da ocorrência: satura em ~1 curtida/s por denúncia.
- Mapa, estatísticas e dados públicos leem até 500 docs por abertura; falta doc agregado.
- Mídia é o custo dominante; comprimir no upload mantém o piloto no Cloudinary grátis.
- As três dependem de `functions/`.
