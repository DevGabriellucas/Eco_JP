# PRODUCTION READINESS AUDIT — ETAPA 17.1
**EcoJP — Sistema de Zeladoria Urbana Colaborativa**

Auditoria realizada: **12 de julho de 2026**  
Auditor: Staff Software Engineer  
Status: ⚠️ **Parcialmente Pronto** (Necessário ações antes de Go-Live)

---

## 📊 MÉTRICAS GERAIS

| Métrica | Valor | Status |
|---|---|---|
| Arquivos Dart (lib/) | 78 | ✅ Controlado |
| Linhas de código | ~20.900 | ⚠️ Verificar arquivos grandes |
| Services | 13 | ✅ Adequado |
| Páginas/Telas | 28+ | ⚠️ Algumas acima de 1000 linhas |
| Testes unitários | 58 | ⚠️ 50% cobertura (piscina pequena) |
| Testes Firestore Rules | 15 | ✅ Bom |
| Arquivos > 1000 linhas | 4 | 🔴 **CRÍTICO** |
| CI/CD configurado | Sim | ✅ Parcial (faltam build APK/IPA) |

---

## 🏗️ ESTRUTURA & ORGANIZAÇÃO

### ✅ Bom
- Separação clara de camadas (pages, widgets, services, models)
- GoRouter configurado e funcional
- Riverpod providers definidos (`lib/features/*/providers/`)
- Repository pattern iniciado (`lib/data/repositories/`)
- Models com serialização correta

### ⚠️ Melhorias Necessárias
1. **Arquitetura em transição** — Coexistem padrões antigos (services diretos) e novos (repositories + providers)
   - `home_page.dart` ainda instancia services diretamente
   - `fila_verificacao_page.dart` não usa providers
   - Mixa comportamentos estatefulwidget com providers

2. **Organização de providers** — Distribuído em `lib/features/` mas nem todas as features o usam
   - `auth_providers.dart` centralizado (bom)
   - Faltam providers para: ocorrências, notificações, moderação

3. **Falta de `models/` estruturado** — Sem pasta `domain/entities` clara
   - Modelos em `lib/models/` com lógica de negócio

---

## 📈 ACOPLAMENTO & RESPONSABILIDADES

### 🔴 Crítico: Widgets Gigantes (>1000 linhas)
```
1. detalhe_ocorrencia_page.dart        1516 linhas (requer split)
2. estatisticas_page.dart              1483 linhas (dashboard monolítico)
3. form_ocorrencia_page.dart           1482 linhas (formulário complexo)
4. occurrence_card.dart                1338 linhas (widget reutilizável, mas gigante)
```

**Impacto:** Dificulta testes, manutenção e debug. Aumenta rebuilds desnecessários.

### 🔴 Crítico: Services Gigantes
```
OcorrenciaService (747 linhas em lib/services/)
  ├─ CRUD ocorrências
  ├─ Comentários
  ├─ Reações (like/dislike)
  ├─ Moderação
  └─ Detalhes de auditoria
```

**Impacto:** Violação de Single Responsibility Principle (SRP).

### ⚠️ Alto Acoplamento
- Pages instanciam services diretamente
- Sem injeção de dependência clara
- Testes de widgets precisam mockar services globais
- Mudança de service afeta múltiplas páginas

---

## 💀 CÓDIGO MORTO

### Encontrado:
- ✅ `a13fea2` commit: "remove código morto e cache de comentários" — já removido

### Verificação atual:
- Sem TODO/FIXME encontrados
- ✅ Imports não utilizados: nenhum (passa no `flutter analyze`)

---

## 🔄 DUPLICAÇÃO

### Patterns repetidos:
1. **Carregamento de dados em StreamBuilder**
   - Repetido em: home_page, perfil_page, estatisticas_page, fila_verificacao_page
   - **Solução:** Extrair em widget `DataStreamBuilder<T>`

2. **Tratamento de erro padrão**
   - Snackbars idênticos em múltiplos lugares
   - **Solução:** `ScaffoldMessengerExtension`

3. **Validação de localização**
   - Ocorre em form_ocorrencia_page, map_controller
   - **Solução:** `LocationValidator` compartilhado

---

## 📦 DEPENDÊNCIAS DESNECESSÁRIAS

### Verificar:
- `node_modules/` na raiz (por quê? não é Node.js)
- `package.json` / `package-lock.json` (verificar se usado)
- `firestore-tests/` duplicado em relação a `test/firestore_rules/`

**Status:** ⚠️ Limpar antes de deploy

---

## ⚡ PERFORMANCE

### Problemas Identificados:

1. **Rebuilds desnecessários**
   - `occurrence_card.dart` (1338 linhas) inteira reconstrói ao trocar like
   - **Solução:** Separar em widgets menores + `ValueKey`

2. **Queries Firestore não otimizadas**
   - `listarFeedComFixadas` carrega TUDO (sem pagination inicial adequada)
   - **Solução:** Implementar infinite scroll com cursor properly

3. **Images não otimizadas**
   - Cloudinary URLs sem transformações (resize, format)
   - **Solução:** Adicionar `?w=400&q=80` ao URL

4. **Cache de comentários**
   - `_commentCountCache` em home_page ocupa memória indefinidamente
   - **Solução:** LRU cache com limite de 100

5. **Sem lazy loading de telas**
   - IndexedStack carrega todas as 5 abas ao iniciar
   - **Solução:** DelayedWidget ou IndexedStack condicional

---

## 🔒 SEGURANÇA

### ✅ Implementado:
- Firestore Rules robustas (624 linhas)
- App Check (Android Play Integrity + Apple App Attest)
- Autenticação verificada por e-mail
- LGPD com consentimento comprovável
- Proteção de denúncias anônimas

### ⚠️ Gaps:

1. **Rate Limiting**
   - Apenas client-side em `rate_limiter.dart`
   - Sem validação server-side (Firestore Rules)
   - **Risco:** Spam em escala

2. **Validação de entrada**
   - Form valida localmente, mas Rules validam de novo
   - Faltam sanitization de strings (XSS em comentários HTML renderizado?)

3. **Secrets**
   - MAPS_API_KEY em `android/local.properties` (bom)
   - Firebase config em `firebase_options.dart` (público — verificar)

4. **Autorização**
   - Verificar se `isAutoridade()` em Firestore Rules roda em cada operação
   - Sem timeout em sessions longas

---

## 🧪 TESTES

### Cobertura Atual:
```
✅ 58 testes unitários Dart
   ├─ Models: 15 casos (bom)
   ├─ Services: 8 casos (cloudinary)
   ├─ Utils: 15 casos (tempo_relativo)
   └─ Páginas: 20 casos (calc_mostaffectedzones)

✅ 15 testes Firestore Rules
   └─ Coverage: Moderar, Auth, Reações, Status
```

### 🔴 Gaps Críticos:
1. **Zero testes de widget** — nenhum OccurrenceCard, HomePage, etc
2. **10 de 13 services sem teste** — OcorrenciaService, AuthService intactos
3. **Zero testes E2E** — fluxo completo cidadão → autoridade não testado
4. **Não integrado ao CI/CD** — Firestore Rules tests não rodade na cada PR

**Impacto:** Risco alto de regressões em produção.

---

## 🎨 UX / UI

### ✅ Positivos:
- Material 3 implementado
- Palette centralizado em `AppTheme`
- Accessibility com Semantics aplicado
- Temas light/dark

### ⚠️ Problemas:

1. **Mensagens de erro genéricas**
   - "Não foi possível concluir a ação" — não diz o quê falhou
   - **Solução:** `ErrorExceptionMapper` com mensagens específicas

2. **Sem estados vazios em algumas telas**
   - FilaVerificacao mostra _FilaVazia
   - HomePage implementa FeedEmptyState
   - Inconsistência

3. **Responsividade**
   - Telas otimizadas para mobile (portrait)
   - Faltam breakpoints para tablet/landscape
   - **Documentação diz:** "não implementado"

4. **Onboarding**
   - Apenas tela `InicialPage` (marketing)
   - Sem tutorial de primeiro uso
   - **Prioridade:** Média

---

## 📱 PLATAFORMAS

### Android
- ✅ `android/settings.gradle.kts` atualizado
- ✅ App Check com Play Integrity
- ⚠️ Sem build de APK automático no CI

### iOS
- ✅ App Check com App Attest (code)
- ⚠️ Sem certificados/provisioning profiles
- ⚠️ Sem build de IPA automático

### Web
- ✅ Firebase config gerada
- ⚠️ Sem deploy automático no Firebase Hosting

---

## 🚀 CI/CD

### ✅ Implementado (.github/workflows/ci.yml):
```yaml
✅ Checkout
✅ Flutter setup + cache
✅ Dart format check (não-bloqueante)
✅ Flutter analyze (bloqueante)
✅ Flutter test (bloqueante)
✅ Firebase Options sintético
✅ MAPS_API_KEY via secrets
```

### 🔴 Faltando:
1. Build APK automático
2. Build IPA automático
3. Testes de Firestore Rules no pipeline
4. SonarQube / Code Coverage report
5. Deploy automático em staging
6. Versionamento automático (SemVer)
7. Release Notes gerados automaticamente

---

## 📊 ESCALABILIDADE

### Suporta até:
- **10–1.000 usuários:** OK com Spark (atual)
- **1.000–10.000:** Exige Cloud Functions + Blaze
- **10.000+:** Exige sharded counters + cache

### Bloqueantes:
1. **Sem Cloud Functions** — impossível:
   - Push notifications
   - Rate limiting server-side
   - Detecção de duplicidade
   - Auditoria server-side

2. **Firestore indexing** — não otimizado para queries grandes

---

## 🎯 RESUMO EXECUTIVO

### Status Geral: ⚠️ **PARCIALMENTE PRONTO**

| Aspecto | Nota | Status |
|---|---|---|
| Arquitetura | 7.5/10 | ⚠️ Transição incompleta (Riverpod/Repository) |
| Código | 6.5/10 | 🔴 4 widgets/services gigantes |
| Testes | 5.0/10 | 🔴 Cobertura baixa, zero E2E |
| Segurança | 8.5/10 | ✅ Regras robustas, mas rate limit fraco |
| Performance | 6.0/10 | ⚠️ Rebuilds desnecessários, queries grandes |
| CI/CD | 6.5/10 | ⚠️ Análise OK, faltam builds e deploy |
| UX/UI | 7.5/10 | ✅ Bom, mas sem onboarding |
| DevOps | 5.0/10 | 🔴 Sem staging, sem versionamento |

### 📋 AÇÕES CRÍTICAS ANTES DE GO-LIVE

**Bloqueantes:**
1. 🔴 Refatorar 4 widgets/services gigantes (> 1000 linhas)
2. 🔴 Adicionar testes de widget para páginas críticas
3. 🔴 Integrar Firestore Rules tests ao CI/CD
4. 🔴 Implementar rate limiting server-side
5. 🔴 Build Android APK automático no CI

**Importantes:**
6. ⚠️ Completar transição Riverpod/Repository
7. ⚠️ Implementar onboarding
8. ⚠️ Deploy staging automático
9. ⚠️ SemVer + Release Notes

**Nice-to-have:**
10. 🟡 Otimizar queries Firestore
11. 🟡 Lazy loading de abas
12. 🟡 Responsividade tablet/landscape

---

## 📅 PRÓXIMAS ETAPAS

1. **ETAPA 17.2** — Revisar módulos (Auth, Home, Mapa, Denúncias, Perfil, Admin, Notificações)
2. **ETAPA 17.3** — Refatoração de código duplicado/morto
3. **ETAPA 17.4** — Performance (rebuilds, imagens, queries)
4. **ETAPA 17.5** — Segurança (rate limit, validação, sanitization)
5. **ETAPA 17.6** — Testes (widget + integração)
6. **ETAPA 17.7** — UX/UI (onboarding, responsividade, mensagens)
7. **ETAPA 17.8** — Admin dashboard
8. **ETAPA 17.9** — CI/CD (builds + deploy)
9. **ETAPA 17.10** — Publicação (Play/App Store)
10. **ETAPA 17.11** — Observabilidade (Crashlytics, Analytics)
11. **ETAPA 17.12** — Checklist Final

---

**Auditoria concluída.**  
Aguardando aprovação para continuar com ETAPA 17.2 (Revisão de Módulos).

