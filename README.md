# 🌱 EcoJP — Aplicativo de Denúncias Ambientais

[![CI](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml/badge.svg)](https://github.com/DevGabriellucas/Eco_JP/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue.svg)](https://flutter.dev)

**EcoJP** é um aplicativo móvel Flutter para cidadãos de **João Pessoa (PB)** denunciarem problemas ambientais e urbanos (lixo, queimadas, buracos, enchentes, esgoto etc.) com foto e localização, acompanharem o andamento oficial e, se quiserem, ficarem anônimos perante a comunidade. Do outro lado, a autoridade recebe uma fila organizada, verifica, encaminha e resolve, e cada passo fica auditado.

Nasceu como projeto de disciplina no Unipê (Centro Universitário de João Pessoa) e virou candidatura institucional: está inscrito no Prêmio de Inovação CSED 2026, será apresentado ao Ministério Público e à reitoria do Unipê e está em fase de piloto com um escritório de advocacia.

---

## 📋 Visão geral

- **Plataformas**: Android 8.0+ e iOS 15.0+
- **Tecnologia**: Flutter + Firebase (Auth, Firestore, App Check, Crashlytics, Analytics) + Cloudinary (fotos e vídeos)
- **Servidor**: não há backend próprio; as Firestore Rules validam toda escrita
- **Testes**: ~190 testes Dart + ~100 testes de regras do Firestore (emulador)
- **CI**: GitHub Actions (formatação, análise, testes, regras e build Android)
- **Status**: piloto; foco em conformidade com a LGPD e em uma demo sem falhas

---

## ✨ Funcionalidades

### Denúncias
- 📍 Localização por GPS ou busca de endereço, restrita ao município de João Pessoa
- 📸 Até 3 fotos ou 1 vídeo, sem metadados EXIF/GPS (removidos antes do upload)
- 🏷️ Categorias: lixo, queimada, buraco, árvore caída, enchente, esgoto, iluminação, outros
- 🕶️ Denúncia anônima: nome, foto e UID não vão para o documento público, e as coordenadas são arredondadas (~100 m)
- 🔗 Compartilhamento com resumo, link do mapa e link direto para o app (`ecojp://`)

### Comunidade
- 📰 Feed paginado; tocar no card abre a denúncia completa
- ❤️ Curtidas e comentários com respostas, curtidas em comentários e emojis
- 🗺️ Mapa com marcadores, mapa de calor e zonas mais afetadas
- 👤 Perfil público, seguir pessoas e conquistas
- 🚛 Guia de coleta de lixo por bairro (cronograma da Emlur)
- 🔔 Notificações de comentários, conquistas e mudanças de status

### Autoridade
- ✅ Fila de verificação por antiguidade
- 📊 Ciclo oficial: pendente → em análise → confirmada → encaminhada → resolvida (ou não confirmada), com evento de auditoria em cada passo
- 🙈 Fila de moderação: ocultar denúncias e comentários abusivos
- 📌 Fixar denúncias prioritárias no feed
- 📈 Painel de estatísticas e relatório em PDF
- O papel é concedido pelo Console do Firebase (coleção `roles`), nunca pelo app

### Conta e privacidade (LGPD)
- 🔑 Login com e-mail/senha (confirmação de e-mail obrigatória para postar) ou Google
- 🪪 Nome público único (reserva atômica)
- 📝 Consentimento registrado com versão e data; novo aceite quando a política muda
- 📤 Exportar meus dados em PDF (inclui denúncias anônimas)
- 🗑️ Excluir conta e dados
- 📱 Uma sessão por conta: entrar em outro aparelho desconecta o anterior

---

## 🚀 Começando

### Pré-requisitos
- **Flutter** 3.47 (stable) — a mesma versão do CI
- **Android SDK** 36 para compilar (o app roda a partir do Android 8.0, minSdk 26)
- **Xcode** para o build iOS
- **Node.js** 20+, **Java** 21 e **Firebase CLI** para os testes de regras

No Windows, `scripts/setup_windows.ps1` automatiza `flutter pub get`, Firebase CLI e FlutterFire CLI.

### Instalação

```bash
git clone https://github.com/DevGabriellucas/Eco_JP.git
cd Eco_JP
flutter pub get
```

Configuração local (nada disso vai para o git):

- `lib/firebase_options.dart` **é** versionado de propósito: a configuração do Firebase de um app cliente não é segredo (a proteção está nas Rules e no App Check).
- Chave do Google Maps em `android/local.properties` (`MAPS_API_KEY=...`).
- Build de release exige `android/key.properties` (ver `.github/workflows/release.yml`) ou, só para teste local, `ECOJP_PERMITIR_RELEASE_DEBUG=true`.
- Opcional: `--dart-define=GOOGLE_MAPS_API_KEY=...` liga o autocomplete de endereços do Google Places (sem ela, o app usa o Photon/OpenStreetMap).

### Rodar o app

```bash
flutter run -d android
flutter run -d ios
```

---

## 🧪 Testes

### Dart (unitários e de widget)

```bash
flutter test
flutter test test/models/ocorrencia_model_test.dart   # um arquivo
```

Cobrem models, repositórios (com `fake_cloud_firestore`), serviços (Cloudinary, geocoding, sessão, rate limiter), controllers do formulário, utilitários (sanitização de texto, privacidade de imagem e vídeo, compartilhamento) e widgets.

### Regras do Firestore

```bash
cd test/firestore_rules
npm ci
npm test        # sobe o emulador e roda o Jest
```

Cobrem autenticação e e-mail verificado, denúncia anônima, moderação, comentários, reações e contadores, auditoria do ciclo oficial, perfis, reserva de nome, notificações, consentimento e sessão. Detalhes em [test/firestore_rules/README.md](test/firestore_rules/README.md).

### Análise e formatação

```bash
flutter analyze
dart format lib test
```

### Carga

Suíte k6 em [`loadtest/`](loadtest/README.md) (`npm run loadtest:seed`, `npm run loadtest:curtidas`, ...).

---

## 📁 Estrutura do projeto

```
Eco_JP/
├── lib/
│   ├── main.dart              # bootstrap: Firebase, App Check, Crashlytics
│   ├── core/                  # rotas (go_router), deep links, tema, sessão única, conectividade
│   ├── features/              # providers Riverpod por domínio (auth, denúncias)
│   ├── data/repositories/     # acesso ao Firestore (ocorrências, comentários)
│   ├── models/                # entidades e (de)serialização
│   ├── services/              # auth, Cloudinary, moderação, notificações, geolocalização…
│   ├── pages/                 # telas (feed, mapa, formulário, perfil, filas da autoridade…)
│   ├── widgets/               # componentes reutilizáveis (card, comentários, ações)
│   ├── theme/                 # cores, tipografia e ThemeData
│   └── utils/                 # funções puras (texto, privacidade de mídia, tempo…)
├── test/
│   ├── firestore_rules/       # testes das regras (Jest + emulador)
│   └── …                      # testes Dart espelhando lib/
├── assets/                    # imagens, ícones, fontes e data/ (cronograma de coleta)
├── docs/                      # PRD, arquitetura, design, regras, tarefas e memória
├── scripts/                   # backfills do Firestore e setup do Windows
├── tools/                     # geocodificação dos bairros
├── loadtest/                  # testes de carga (k6)
├── firestore.rules            # regras de segurança comentadas
└── firestore.indexes.json     # índices compostos
```

---

## 🔐 Segurança

1. **Nada confia no cliente** — toda escrita é validada nas Firestore Rules (campos, dono, papel, e-mail verificado, área de João Pessoa, intervalo entre reações, auditoria no mesmo batch).
2. **Negação por padrão** — coleção sem regra explícita cai em `allow read, write: if false`.
3. **Firebase App Check** — ativo no app; a imposição no Console depende de registrar o novo ID `br.com.ecojp.app`.
4. **Nenhum segredo no repositório** — `google-services.json`, `key.properties`, `local.properties` e `.env` estão no `.gitignore`.

### Implantação das regras

Quando as regras mudam de forma incompatível, a ordem é: publicar o app → `firebase deploy --only firestore:indexes` → backfills (`npm run backfill:oculto`, `npm run backfill:nomes`) → `firebase deploy --only firestore:rules`. Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#8-implantação).

---

## 📚 Documentação

- **[docs/PRD.md](docs/PRD.md)** — requisitos do produto: problema, escopo, métricas e riscos
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — como o sistema é montado, modelo de dados e fluxos
- **[docs/DESIGN.md](docs/DESIGN.md)** — cores, tipografia, componentes e acessibilidade
- **[docs/RULES.md](docs/RULES.md)** — regras para quem mexe no código (inclusive agentes de IA)
- **[docs/TASKS.md](docs/TASKS.md)** — tarefas e pendências atuais
- **[docs/MEMORY.md](docs/MEMORY.md)** — decisões e armadilhas não óbvias
- **[ROADMAP.md](ROADMAP.md)** — plano de evolução por fases (defasado em alguns itens; na dúvida, vale o TASKS)

---

## 🔄 CI/CD

`.github/workflows/ci.yml` roda a cada push:

1. **Formatação** — `dart format --set-exit-if-changed` (bloqueia)
2. **Análise estática** — `flutter analyze`
3. **Testes Dart** — `flutter test`
4. **Regras do Firestore** — testes no emulador (Java 21 + Node 20)
5. **Build Android** — APK de release como artefato (depende dos passos 1–3)

`.github/workflows/release.yml` assina o build com secrets e versiona pela tag.

---

## 📊 Status

| Componente | Status | Notas |
|-----------|--------|-------|
| App Flutter | ✅ Funcional | ~190 testes passando |
| Firestore Rules | ✅ Publicadas | ~100 testes de segurança |
| Firebase App Check | 🟡 Ativo no app, sem imposição | Ligar no Console depois de registrar os apps com o novo ID |
| LGPD | 🟡 Em progresso | Falta apagar mídia do Cloudinary e anonimizar comentários na exclusão de conta; revisão jurídica da política |
| Escala | 🟡 Piloto | Reações em array e telas que leem até 500 docs; soluções dependem de Cloud Functions |
| Dark mode | 🟡 Parcial | Algumas telas ainda só no tema claro |

Pendências detalhadas em [docs/TASKS.md](docs/TASKS.md).

---

## 🤝 Contribuindo

1. Leia [docs/RULES.md](docs/RULES.md).
2. Crie uma branch a partir de `Develop` (`feature/<nome-curto>`).
3. Commits no padrão Conventional Commits, em português (`feat(escopo): ...`, `fix: ...`).
4. Abra o Pull Request para `Develop`; `main` só recebe merge de `Develop` com CI verde.

**Requisitos para PR:** `dart format` aplicado, `flutter analyze` limpo, testes Dart e de regras passando, e teste novo para bug corrigido.

---

## 📝 Licença

Licença ainda não definida (o repositório não tem arquivo `LICENSE`). Até isso ser decidido, todos os direitos são reservados ao autor.

---

## 👥 Equipe

- **Desenvolvedor**: Gabriel Lucas
- **Instituição**: Unipê — Centro Universitário de João Pessoa

## 📞 Suporte

Para dúvidas ou sugestões, abra uma [issue no GitHub](https://github.com/DevGabriellucas/Eco_JP/issues).

---

**Última atualização:** outubro de 2026 | **Versão:** 1.0.0
