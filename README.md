# 🌱 EcoJP — Aplicativo de Denúncias Ambientais

[![CI](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml/badge.svg)](https://github.com/DevGabriellucas/Eco_JP/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue.svg)](https://flutter.dev)

**EcoJP** é um aplicativo móvel Flutter que permite que cidadãos denunciem problemas ambientais na Paraíba (buracos, lixo, queimadas, enchentes, etc.) com segurança, privacidade e conformidade com a LGPD. Nasceu como projeto de disciplina no Unipê (Centro Universitário de João Pessoa) e evoluiu para produto: está inscrito no Prêmio de Inovação CSED 2026 e em fase de piloto com um escritório de advocacia.

---

## 📋 Visão Geral

- **Plataformas**: Android, iOS
- **Tecnologia**: Flutter + Firebase (Firestore, Auth, Cloud Storage/Cloudinary)
- **Segurança**: Firestore Rules robustas, Firebase App Check, validação de email
- **Testes**: 180+ testes Dart + 99 testes de regras Firestore (emulador)
- **CI/CD**: GitHub Actions (análise, testes, build)
- **Status**: Fase de blindagem de segurança e conformidade legal (LGPD)

---

## ✨ Features

### Denúncias Ambientais
- 📍 Geolocalização com mapa interativo
- 📸 Upload de até 3 fotos (processadas com Cloudinary)
- 🏷️ Categorias: Lixo, Queimada, Buraco, Árvores caídas, Enchentes, Esgoto, Iluminação, Outros
- 🔐 Denúncias anônimas (sem exposição do UID no documento público)
- ⭐ Sistema de reações (likes/dislikes)
- 💬 Comentários com modração por autoridade

### Autenticação e Segurança
- 🔑 Google Sign-In + Email/Senha via Firebase Auth
- ✉️ Verificação de email obrigatória para denunciar
- 🛡️ Firebase App Check (impede abuso via scripts)
- 🔒 Regras Firestore validam toda escrita no servidor
- 🚫 Negação por padrão (principle of least privilege)

### Autoridade (Moderação)
- ✅ Verificação de denúncias pendentes
- 📊 Status oficial (Pendente / Em análise / Resolvido / Não resolvido)
- 🙈 Ocultação de conteúdo por abuso (LGPD art. 17)
- 📋 Histórico auditável de ações
- 📌 Fixação de denúncias prioritárias

### Privacidade e Conformidade
- 🔐 LGPD: opção de exclusão de conta (apaga dados + consentimento)
- 🔍 Sem metadados EXIF em fotos (previne reidentificação)
- 📝 Histórico de auditoria para rastreabilidade
- 🌙 Dark mode completo (sem dados sensíveis em cores)

---

## 🚀 Começando

### Pré-requisitos
- **Flutter** 3.0+ ([instalar](https://flutter.dev/docs/get-started/install))
- **Android** 8.0+ (minSdk 26) para rodar; SDK 36 para compilar
- **Xcode** 14+ (para build iOS)
- **Firebase CLI** (para testes do Firestore)
- **Node.js** 20+ (para rodar testes de regras)

### Instalação

```bash
# Clone o repositório
git clone https://github.com/DevGabriellucas/Eco_JP.git
cd Eco_JP

# Instale dependências Flutter
flutter pub get

# lib/firebase_options.dart é versionado: a configuração do Firebase de um
# app cliente não é segredo (a proteção está nas Rules e no App Check).
# A chave do Google Maps vai em android/local.properties (MAPS_API_KEY=...).
# Build de release exige android/key.properties (ver .github/workflows/release.yml)
# ou, só para teste local, ECOJP_PERMITIR_RELEASE_DEBUG=true.
```

### Rodar o App

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web (em desenvolvimento)
flutter run -d web
```

---

## 🧪 Testes

### Testes Flutter (145+ testes unitários)

```bash
# Rodar todos os testes
flutter test

# Rodar com cobertura
flutter test --coverage

# Teste específico
flutter test test/models/ocorrencia_model_test.dart
```

**Cobertura:**
- Models (Ocorrência, StatusOficial, Usuário, etc.)
- Services (Cloudinary, Rate Limiter, Geolocation)
- Utils (Sanitização, Validação, Formatação)
- Widgets (FeedEmptyState, InicialPage)
- Controllers (LocationController, MediaController)

### Testes de Regras Firestore (24 testes)

```bash
# Do diretório raiz
cd test/firestore_rules
npm ci
npm test

# Ou rodar com Firebase CLI
firebase emulators:exec --only firestore "jest --runInBand"
```

**Cobertura:**
- Autenticação e verificação de email
- Denúncias anônimas (proteção do UID)
- Moderação (só autoridade pode)
- Comentários e reações
- Auditoria (imutabilidade)

### Análise Estática

```bash
# Lint + type checking
flutter analyze

# Formatação
dart format lib test
```

---

## 📁 Estrutura do Projeto

```
eco_jp/
├── lib/
│   ├── main.dart                      # Entrada do app
│   ├── config/                        # Configuração (Firebase, Riverpod)
│   ├── models/                        # Entidades (OcorrenciaModel, UsuarioModel)
│   ├── data/                          # Repositórios (Firebase) e Data sources
│   ├── services/                      # Serviços (Cloudinary, Geolocation)
│   ├── utils/                         # Utilitários (sanitização, formatação)
│   ├── pages/                         # Telas do app
│   │   ├── feed/                      # Feed de denúncias
│   │   ├── form_ocorrencia/           # Formulário de denúncia
│   │   ├── perfil/                    # Perfil do usuário
│   │   ├── autoridade/                # Painel de autoridade
│   │   └── ...
│   └── widgets/                       # Componentes reutilizáveis
├── test/
│   ├── firestore_rules/               # Testes das regras Firestore
│   │   ├── firestore.rules.test.js
│   │   ├── package.json
│   │   ├── firebase.json
│   │   └── ...
│   ├── models/                        # Testes unitários
│   ├── services/
│   ├── utils/
│   └── ...
├── assets/
│   ├── images/                        # Imagens (logo, ícones)
│   └── ...
├── firestore.rules                    # Regras de segurança Firestore
├── firebase.json                      # Configuração Firebase (emulador, etc)
├── pubspec.yaml                       # Dependências Flutter
└── README.md                          # Este arquivo
```

---

## 🔐 Segurança

### Princípios

1. **Validação no servidor** — Todas as denúncias, comentários e reações são validadas pelas Firestore Rules
2. **Sem confiança no cliente** — O app envia dados, mas o servidor decide se aceita
3. **Negação por padrão** — `allow read, write: if false` em coleções não mapeadas
4. **Firebase App Check** — Impede que scripts externos usem as credenciais públicas do Firebase

### Firestore Rules

- ✅ Leitura exige autenticação
- ✅ Escrita de conteúdo exige email verificado
- ✅ Denúncia anônima não grava UID no documento público
- ✅ Reações via transação (integridade dos contadores)
- ✅ Moderação (ocultação) só para autoridade
- ✅ Histórico de auditoria imutável

Veja `firestore.rules` para detalhes.

### LGPD

- ✅ Opção de exclusão de conta (deleta denúncias do usuário)
- ✅ Consentimento rastreável
- ✅ Sem metadados EXIF em fotos
- ✅ Histórico auditável das ações oficiais (verificação, status, reversão)

---

## 📚 Documentação

- **[ROADMAP.md](ROADMAP.md)** — Plano de evolução (Fase 1: Segurança, Fase 2: Conformidade, etc.)
- **[docs/adr/](docs/adr/)** — Decisões de arquitetura (ex.: Firebase vs. Supabase)
- **[docs/Code-review.md](docs/Code-review.md)** — Revisão de código que originou a Sprint 1
- **[test/firestore_rules/README.md](test/firestore_rules/README.md)** — Como rodar os testes de regras
- **[firestore.rules](firestore.rules)** — Regras de segurança comentadas

---

## 🔄 CI/CD

GitHub Actions roda a cada push:

1. **Análise estática** — `flutter analyze`
2. **Formatação** — `dart format` (aviso se fora do padrão)
3. **Testes Flutter** — 145+ testes unitários
4. **Testes Firestore** — 24 testes de regras (emulador)
5. **Build Android** — APK release (dependente de análise passar)

Veja `.github/workflows/ci.yml` para detalhes.

---

## 🛠️ Desenvolvimento

### Setup Local

```bash
# Instalar dependências
flutter pub get

# Atualizar pubspec.lock
flutter pub upgrade

# Limpar cache
flutter clean
flutter pub get
```

### Pre-commit Hooks (opcional)

```bash
# Instalar dart_pre_commit
pub global activate dart_pre_commit

# Adicionar ao git hooks
dart_pre_commit install
```

### Emuladores Firebase

```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Rodar emuladores (Firestore + Auth)
firebase emulators:start

# Em outra aba, rodar testes contra emulador
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 flutter test
```

---

## 📊 Status

| Componente | Status | Notas |
|-----------|--------|-------|
| Flutter App | ✅ Funcional | 180+ testes passando |
| Firestore Rules | ✅ Robusto | 99 testes de segurança |
| Firebase App Check | 🟡 Ativado no app, sem imposição | Android (Play Integrity), iOS (App Attest), web (reCAPTCHA v3, chave por `--dart-define`). Ligar a imposição no Console depois de registrar os apps com o novo ID |
| LGPD Compliance | 🟡 Em progresso | Exclusão de conta + histórico |
| Dark Mode | 🟡 Parcial | Auth + algumas telas |
| Docs | 🟡 Parcial | README + ROADMAP + ADR |

---

## 🤝 Contribuindo

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'feat: adicionar MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

**Requisitos para PR:**
- ✅ Testes passando (`flutter test` + `firestore rules test`)
- ✅ Análise estática passando (`flutter analyze`)
- ✅ Código formatado (`dart format`)
- ✅ Descrição clara da mudança

---

## 📝 Licença

Licença ainda não definida (o repositório não tem arquivo `LICENSE`). Até isso ser decidido, todos os direitos são reservados ao autor.

---

## 👥 Equipe

- **Desenvolvedor**: Gabriel Lucas
- **Instituição**: Unipê — Centro Universitário de João Pessoa

---

## 📞 Suporte

Para dúvidas ou sugestões, abra uma [issue no GitHub](https://github.com/DevGabriellucas/Eco_JP/issues).

---

**Última atualização:** Agosto 2026 | **Versão:** 1.0.0
