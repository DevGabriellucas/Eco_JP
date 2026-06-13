<div align="center">

# 🌱 EcoJP

**Aplicativo de zeladoria urbana ambiental para João Pessoa**

[![CI](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml/badge.svg)](https://github.com/DevGabriellucas/Eco_JP/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Cloudinary](https://img.shields.io/badge/Cloudinary-imagens-3448C5?logo=cloudinary&logoColor=white)
![Status](https://img.shields.io/badge/status-MVP%20funcional-success)

*Projeto da disciplina de Desenvolvimento Mobile — UNIPÊ*

</div>

---

O **EcoJP** é uma aplicação mobile que apoia o registro e o acompanhamento de ocorrências ambientais na cidade de João Pessoa. O foco é facilitar a participação cidadã: moradores relatam problemas urbanos — descarte irregular de lixo, esgoto a céu aberto, queimadas, alagamentos, árvores caídas e falta de iluminação — e acompanham a evolução de cada denúncia.

## 📱 Funcionalidades

| | Funcionalidade |
|---|---|
| 🔐 | Cadastro, login (e-mail/senha e **Google Sign-In**) e recuperação de senha |
| 📝 | Registro de denúncias com **foto, categoria e geolocalização** automática |
| 🗺️ | **Mapa interativo** com marcadores coloridos por categoria |
| 📰 | Feed em tempo real com **busca, filtro por tipo e por status** |
| 👍 | Curtidas, descurtidas e **comentários** em cada denúncia |
| 🔔 | **Notificações** quando interagem com suas denúncias |
| 📊 | **Painel de estatísticas** por status, categoria e dia da semana |
| 👤 | Perfil editável com foto, bio e bairro |
| ✏️ | Dono da denúncia pode **editar, alterar status e excluir** |
| ⚖️ | Documentos legais (LGPD, termos de uso) |

## 📸 Screenshots

> _Adicione aqui capturas das telas principais (feed, mapa, formulário e estatísticas)._
> _Sugestão: salve as imagens em `docs/screenshots/` e referencie com tabelas de 3 colunas._

## 🛠️ Stack

- **[Flutter](https://flutter.dev)** + **Dart** — aplicação multiplataforma (Android, iOS e Web)
- **[Firebase Authentication](https://firebase.google.com/docs/auth)** — autenticação de usuários
- **[Cloud Firestore](https://firebase.google.com/docs/firestore)** — banco de dados em tempo real, protegido por regras de segurança rigorosas (`firestore.rules`)
- **[Cloudinary](https://cloudinary.com)** — armazenamento e CDN de imagens
- **[Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)** — mapa de ocorrências
- **Geolocator + Geocoding** — localização do dispositivo e conversão em endereço

## 🏗️ Arquitetura

O projeto separa interface, regras de negócio e integrações externas:

```
lib/
├── main.dart                  # Bootstrap, rotas e AuthCheck
├── models/                    # Entidades e enums de domínio
│   ├── ocorrencia_model.dart
│   ├── comentario_model.dart
│   └── occurrence_types.dart  # Tipos/status compartilhados pelo app inteiro
├── services/                  # Comunicação com serviços externos
│   ├── auth_service.dart      # Firebase Auth (e-mail, Google, recuperação)
│   ├── ocorrencia_service.dart# CRUD + likes transacionais + comentários
│   ├── cloudinary_service.dart# Upload de imagens (testável, config injetável)
│   ├── notificacao_service.dart
│   ├── usuario_service.dart
│   └── geolocation/           # GPS e validações de coordenadas
├── widgets/                   # Componentes reutilizáveis
│   ├── occurrence_card.dart   # Card do feed (slider de fotos, reações)
│   ├── ocorrencia_actions.dart# Menu do dono (status/editar/excluir)
│   └── feed_states.dart       # Skeleton de carregamento, vazio e erro
└── pages/                     # Telas
    ├── home_page.dart         # Feed com busca e filtros
    ├── mapPage/               # Mapa (controller + widgets)
    ├── form_ocorrencia_page.dart
    ├── detalhe_ocorrencia_page.dart
    ├── estatisticas_page.dart
    ├── perfil/                # Perfil e edição
    └── ...
```

**Destaques técnicos:**

- Curtidas usam **transações do Firestore** para evitar condições de corrida.
- O feed diferencia estados de **carregando (skeleton animado)**, **erro (com retry)** e **vazio** (com atalho para limpar filtros).
- As regras do Firestore validam **schema completo** na criação e restringem cada tipo de atualização ao seu autor.

## 🚀 Como rodar

**Pré-requisitos:** Flutter 3.x instalado e um dispositivo/emulador Android.

```bash
# 1. Clone o repositório
git clone https://github.com/DevGabriellucas/Eco_JP.git
cd Eco_JP

# 2. Instale as dependências
flutter pub get

# 3. Configure as chaves de API locais
#    Siga o passo a passo em CONFIGURACAO.md

# 4. Rode o app
flutter run
```

> 🔑 As chaves de API **não são versionadas**. Veja [`CONFIGURACAO.md`](CONFIGURACAO.md) para o setup completo (Google Maps, Cloudinary e Firebase). O Cloudinary do EcoJP já tem `cloud name` e preset unsigned padrão no app; use `--dart-define` apenas para trocar de ambiente.

## ✅ Qualidade

O repositório roda **integração contínua** via GitHub Actions a cada push e pull request:

| Etapa | Comando |
|---|---|
| Formatação | `dart format --set-exit-if-changed` |
| Análise estática | `flutter analyze` |
| Testes unitários | `flutter test` |

Para rodar os testes localmente:

```bash
flutter test
```

Os testes cobrem os parsers de categoria/status, a serialização do `OcorrenciaModel` e o `CloudinaryService` (com cliente HTTP mockado — sem tocar a rede).

## 🗄️ Modelagem de dados

A modelagem NoSQL do Firestore está documentada em [`docs/`](docs/):

- `ocorrencias/{id}` — denúncia com autor, localização, reações e contadores
- `ocorrencias/{id}/comentarios/{id}` — subcoleção de comentários
- `usuarios/{uid}` — perfil público (nome, bio, bairro, foto)
- `usuarios/{uid}/notificacoes/{id}` — notificações do usuário

## 👥 Equipe

| Integrante | Responsabilidade |
| --- | --- |
| **Gabriel Lucas** | Arquitetura, Firebase e integração |
| **Fernando Nazário** | Back-end, mapa e câmera |
| **Alik Breno** | Front-end Flutter |
| **Marcos Manoel** | UI/UX e prototipagem |
| **Jonatha Cavalcanti** | Engajamento e CRUDs |

---

<div align="center">

Feito com 💚 em João Pessoa — PB

</div>
