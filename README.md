# EcoJP — Denúncias Ambientais

[![CI](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml/badge.svg)](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Plataformas](https://img.shields.io/badge/plataformas-Android%20%7C%20iOS-lightgrey)

**EcoJP** é um aplicativo móvel para cidadãos de **João Pessoa (PB)** registrarem problemas ambientais e urbanos (lixo, queimadas, buracos, enchentes, esgoto e outros) com foto e localização. O cidadão acompanha o andamento oficial da denúncia e pode optar pelo anonimato perante a comunidade. Do lado da autoridade, o app organiza uma fila de verificação, encaminha e resolve cada caso, e registra um evento de auditoria em cada etapa.

O projeto nasceu como trabalho da disciplina no Unipê (Centro Universitário de João Pessoa) e está inscrito no Prêmio de Inovação CSED 2026. Está em fase de piloto com um escritório de advocacia e será apresentado ao Ministério Público e à reitoria do Unipê.

## Sumário

- [Visão geral](#visão-geral)
- [Funcionalidades](#funcionalidades)
- [Começando](#começando)
- [Testes](#testes)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Segurança](#segurança)
- [CI/CD](#cicd)
- [Documentação](#documentação)
- [Status](#status)
- [Contribuindo](#contribuindo)
- [Licença e contato](#licença-e-contato)

## Visão geral

| Item | Detalhe |
|---|---|
| Plataformas | Android 8.0+ (minSdk 26) e iOS 15.0+ |
| Frontend | Flutter 3.47.2, Riverpod, go_router |
| Backend | Sem servidor próprio: Firebase Auth, Firestore, App Check, Crashlytics e Analytics. Mídia no Cloudinary |
| Segurança de escrita | Firestore Rules validam toda escrita no servidor |
| Testes | 195 testes Dart (unitários e de widget) e 124 testes de regras no emulador do Firestore |
| CI | GitHub Actions: formatação, análise, testes, regras e build Android |
| Versão | 1.0.0 (piloto) |

## Funcionalidades

### Denúncias
- Localização por GPS ou busca de endereço, restrita ao município de João Pessoa
- Até 3 fotos ou 1 vídeo, com metadados EXIF/GPS removidos antes do envio
- Categorias: lixo, queimada, buraco, árvore caída, enchente, esgoto, iluminação e outros
- Denúncia anônima: nome, foto e UID não vão ao documento público, e as coordenadas são arredondadas (~100 m)
- Compartilhamento com resumo, link do mapa e link direto para o app (`ecojp://`)

### Comunidade
- Feed paginado; ao tocar em um card, abre-se a denúncia completa
- Curtidas e comentários com respostas, curtidas em comentários e emojis
- Mapa com marcadores, mapa de calor e zonas mais afetadas
- Perfil público, seguir pessoas e conquistas
- Guia de coleta de lixo por bairro (cronograma da Emlur)
- Notificações de comentários, conquistas e mudanças de status

### Autoridade
- Fila de verificação por antiguidade
- Ciclo oficial: pendente → em análise → confirmada → encaminhada → resolvida (ou não confirmada), com evento de auditoria em cada passo
- Fila de moderação para ocultar denúncias e comentários abusivos
- Fixação de denúncias prioritárias no feed
- Painel de estatísticas e relatório em PDF
- O papel é concedido pelo Console do Firebase (coleção `roles`), nunca pelo app

### Conta e privacidade (LGPD)
- Login com e-mail/senha (confirmação de e-mail obrigatória para publicar) ou Google
- Nome público único, reservado de forma atômica
- Consentimento registrado com versão e data, com novo aceite quando a política muda
- Exportação dos próprios dados em PDF (inclui denúncias anônimas)
- Exclusão de conta e dos dados
- Uma sessão por conta: entrar em outro aparelho desconecta o anterior

## Começando

### Pré-requisitos

- **Flutter** 3.47.2 (stable), a mesma versão do CI
- **Android SDK** 36 para compilar
- **Xcode** para o build iOS
- **Node.js** 20+, **Java** 21 e **Firebase CLI** para os testes de regras

No Windows, `scripts/setup_windows.ps1` automatiza `flutter pub get`, a Firebase CLI e a FlutterFire CLI.

### Instalação

```bash
git clone https://github.com/DevGabriellucas/Eco_JP.git
cd Eco_JP
flutter pub get
```

### Configuração local

Os itens abaixo ficam fora do git:

- `lib/firebase_options.dart` **é versionado de propósito**. A configuração do Firebase de um app cliente não é segredo; a proteção está nas Rules e no App Check.
- Chave do Google Maps em `android/local.properties` (`MAPS_API_KEY=...`).
- Build de release exige `android/key.properties` (ver `.github/workflows/release.yml`). Para teste local, use `ECOJP_PERMITIR_RELEASE_DEBUG=true`.
- Opcional: `--dart-define=GOOGLE_MAPS_API_KEY=...` ativa o autocomplete de endereços pelo Google Places. Sem ela, o app usa o Photon (OpenStreetMap).

### Executar

```bash
flutter run -d android
flutter run -d ios
```

## Testes

### Dart (unitários e de widget)

```bash
flutter test
flutter test test/models/ocorrencia_model_test.dart   # um arquivo
```

Cobrem models, repositórios (com `fake_cloud_firestore`), serviços (Cloudinary, geocodificação, sessão, rate limiter), controllers do formulário, utilitários (sanitização de texto, privacidade de imagem e vídeo, compartilhamento) e widgets.

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

Suíte k6 em [`loadtest/`](loadtest/README.md), com resultados em [`loadtest/RESULTADOS.md`](loadtest/RESULTADOS.md).

## Estrutura do projeto

```
Eco_JP/
├── lib/
│   ├── main.dart              # inicialização: Firebase, App Check, Crashlytics
│   ├── core/                  # rotas (go_router), deep links, tema, sessão única, conectividade
│   ├── features/              # providers Riverpod por domínio (auth, denúncias)
│   ├── data/repositories/     # acesso ao Firestore (ocorrências, comentários)
│   ├── models/                # entidades e (de)serialização
│   ├── services/              # auth, Cloudinary, moderação, notificações, geolocalização
│   ├── pages/                 # telas (feed, mapa, formulário, perfil, filas da autoridade)
│   ├── widgets/               # componentes reutilizáveis (card, comentários, ações)
│   ├── theme/                 # cores, tipografia e ThemeData
│   └── utils/                 # funções puras (texto, privacidade de mídia, tempo)
├── test/
│   ├── firestore_rules/       # testes das regras (Jest + emulador)
│   └── …                      # testes Dart espelhando lib/
├── assets/                    # imagens, ícones, fontes e dados (cronograma de coleta)
├── docs/                      # PRD, arquitetura, design, regras, tarefas e memória
├── scripts/                   # manutenção do Firestore (backfills, limpeza) e setup do Windows
├── tools/                     # geocodificação dos bairros
├── loadtest/                  # testes de carga (k6)
├── firestore.rules            # regras de segurança
└── firestore.indexes.json     # índices compostos
```

## Segurança

1. **Nada confia no cliente.** Toda escrita é validada nas Firestore Rules: campos, dono, papel, e-mail verificado, área de João Pessoa, intervalo entre reações e auditoria no mesmo batch.
2. **Negação por padrão.** Coleção sem regra explícita cai em `allow read, write: if false`.
3. **Firebase App Check** ativo no app. A imposição no Console depende do registro dos apps com o ID `br.com.ecojp.app`.
4. **Nenhum segredo versionado.** `google-services.json`, `key.properties`, `local.properties` e `.env` estão no `.gitignore`.

### Implantação das regras

Quando as regras mudam de forma incompatível, a ordem é: publicar o app → `firebase deploy --only firestore:indexes` → backfills (`npm run backfill:oculto`, `npm run backfill:nomes`) → `firebase deploy --only firestore:rules`. Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#8-implantação).

## CI/CD

`.github/workflows/ci.yml` roda a cada push e pull request para `main` e `Develop`:

1. **Formatação**: `dart format --set-exit-if-changed`
2. **Análise estática**: `flutter analyze`
3. **Testes Dart**: `flutter test`
4. **Regras do Firestore**: testes no emulador (Java 21 e Node 20)
5. **Build Android**: APK de release como artefato

`.github/workflows/release.yml` assina o build com secrets e versiona pela tag.

## Documentação

| Documento | Conteúdo |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Requisitos do produto: problema, escopo, métricas e riscos |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura, modelo de dados, fluxos e implantação |
| [docs/DESIGN.md](docs/DESIGN.md) | Cores, tipografia, componentes e acessibilidade |
| [docs/RULES.md](docs/RULES.md) | Regras para quem altera o código (inclusive agentes de IA) |
| [docs/TASKS.md](docs/TASKS.md) | Tarefas e pendências atuais |
| [docs/MEMORY.md](docs/MEMORY.md) | Decisões e armadilhas não óbvias |
| [ROADMAP.md](ROADMAP.md) | Plano de evolução por fases (em parte defasado; na dúvida, vale o TASKS) |

## Status

| Componente | Status | Notas |
|---|---|---|
| App Flutter | Funcional | 195 testes Dart |
| Firestore Rules | Publicadas | 124 testes de segurança |
| Firebase App Check | Ativo no app, sem imposição | Ligar no Console após registrar os apps com o novo ID |
| LGPD | Em andamento | Falta apagar mídia no Cloudinary e anonimizar comentários na exclusão de conta; revisão jurídica da política |
| Escala | Piloto | Reações em array e telas que leem até 500 documentos; as soluções dependem de Cloud Functions |
| Tema escuro | Parcial | Algumas telas ainda usam só o tema claro |

Pendências detalhadas em [docs/TASKS.md](docs/TASKS.md).

## Contribuindo

1. Leia [docs/RULES.md](docs/RULES.md).
2. Crie a branch a partir de `Develop` com o padrão `feature/<nome-curto>`.
3. Faça commits no padrão Conventional Commits, em português (`feat(escopo): ...`, `fix: ...`).
4. Abra o Pull Request para `Develop`. A `main` recebe apenas merge da `Develop` com o CI verde.

**Requisitos para PR:** `dart format` aplicado, `flutter analyze` limpo, testes Dart e de regras passando e um teste novo para cada bug corrigido.

## Licença e contato

- **Licença:** ainda não definida (o repositório não tem arquivo `LICENSE`). Até que seja definida, todos os direitos são reservados ao autor.
- **Desenvolvedor:** Gabriel Lucas
- **Instituição:** Unipê — Centro Universitário de João Pessoa
- **Dúvidas e sugestões:** [issues no GitHub](https://github.com/DevGabriellucas/Eco_JP/issues)

---

*Última atualização: outubro de 2026 · Versão 1.0.0*
