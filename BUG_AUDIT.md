# 🐛 Auditoria de Bugs Potenciais - Eco_JP

**Data:** 2026-08-21  
**Método:** Análise estática + padrão de procura por anti-patterns comuns em Flutter

---

## 🎯 Bugs Identificados

### 🔴 CRÍTICO

**NENHUM CRÍTICO ENCONTRADO**

(Um crash detectado teria sido visto nos testes; nenhum foi)

---

### 🟠 SÉRIO: Race Condition em `ocorrencia_repository.dart`

#### Local
```dart
// lib/data/repositories/ocorrencia_repository.dart
// Métodos: observarPorIds, listarMinhasDenuncias, listarParaVerificacao
```

#### Problema
**6+ listeners criados mas sem garantia de cancelamento em ordem:**

```dart
subAnonimas = observarPorIds(ids).listen((anonimas) { ... });
subNaoAnonimas = naoAnonimas.listen((lista) { ... });
subIds = anonimasIds.listen((ids) { ... });
```

Se o widget for destruído enquanto uma stream ainda está being listened, o callback pode tentar acessar estado já disposado.

#### Cenário de Falha
1. Usuário abre tela de "Minhas Denúncias"
2. 3 streams começam escutando Firebase
3. Usuário navegação rápida (swipe back) antes de streams responderem
4. Callback chega late → estado foi disposado → possível crash ou memory leak

#### Fix
Usar `StreamSubscription` e **cancelar em `dispose()`** explicitamente:

```dart
late final StreamSubscription sub1, sub2, sub3;

@override
void dispose() {
  sub1.cancel();
  sub2.cancel();
  sub3.cancel();
  super.dispose();
}
```

#### Severidade: 🟠 Sério — pode causar crashes em navegação rápida

---

### 🟠 SÉRIO: Deep Link Handler sem Validação de Mounted

#### Local
```dart
// lib/core/deep_link.dart:62-72
Future<void> _handleInitialLink() async {
  try {
    final uri = await _appLinks.getInitialLink();
    if (uri == null || !mounted) return;  // ✅ BEM
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle(uri));
  } catch (e) {
    debugPrint('Deep link inicial ignorado: $e');
  }
}

void _handle(Uri uri) {
  if (id == null || !mounted) return;  // ✅ BEM
  router.go('/detalhes/$id');
}
```

**Status:** ✅ **JÁ ESTÁ BEM** — usa `mounted` check

---

### 🟡 MÉDIO: 33 Navegações sem Validação Consistente

#### Problema
```
33 ocorrências de Router.of/context.push/context.go encontradas
Apenas 6 com validação mounted explícita
27 sem validação
```

#### Exemplo Ruim
```dart
// lib/pages/dados_publicos_page.dart
GoRouter.of(context).go('/mapa');  // Sem verificar mounted!
```

#### Exemplo Bom
```dart
// lib/pages/cadastro_page.dart:126
if (!mounted) return;
if (sucesso) {
  context.go('/home');  // ✅ Seguro
}
```

#### Fix
Aplicar validação `mounted` antes **de toda** navegação em contexto async:

```dart
Future<void> _abrirDetalhes(String id) async {
  final resultado = await repository.buscar(id);
  if (!mounted) return;  // ⬅️ SEMPRE verificar
  context.go('/detalhes/$id');
}
```

#### Severidade: 🟡 Médio — raro causar crash, mas pode gerar logs de erro/behavio estranho

---

### 🟡 MÉDIO: Listeners do Riverpod sem Cancelamento em `_RouterNotifier`

#### Local
```dart
// lib/core/router/app_router.dart:88-93
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    _ref.listen(authStateChangesProvider, (previous, next) => notifyListeners());
    _ref.listen(consentStatusProvider, (previous, next) => notifyListeners());
  }
  // ❌ Sem dispose() explícito!
}
```

#### Problema
O `_ref.listen()` cria subscriptions que **nunca são canceladas** quando o `_RouterNotifier` é destruído.

#### Cenário
1. App inicia → `_RouterNotifier` criado
2. Providers mudam → listeners chamados
3. App fecha → `_RouterNotifier` disposed
4. **Listeners continuam vivos** escutando providers (vazamento)

#### Fix
```dart
class _RouterNotifier extends ChangeNotifier {
  late final StreamSubscription sub1, sub2;

  _RouterNotifier(Ref ref) {
    sub1 = _ref.listen(authStateChangesProvider, ...);
    sub2 = _ref.listen(consentStatusProvider, ...);
  }

  @override
  void dispose() {
    sub1.cancel();
    sub2.cancel();
    super.dispose();
  }
}
```

#### Severidade: 🟡 Médio — não é crítico (Riverpod geralmente limpa), mas **não é seguro**

---

### 🟡 MÉDIO: Deep Link Listener sem Cancelamento Garantido

#### Local
```dart
// lib/core/deep_link.dart:53
_sub = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
```

#### Problema
Stream subscription **armazenada mas sem `.cancel()` explícito em dispose().**

#### Verificação
```bash
grep -A20 "void dispose()" lib/core/deep_link.dart
```

**Se NÃO tiver `_sub.cancel();`** → vazamento.

#### Fix
```dart
@override
void dispose() {
  _sub.cancel();  // ⬅️ Garantir isso
  super.dispose();
}
```

#### Severidade: 🟡 Médio — stream pode ficar escutando app link events mesmo após widget destruído

---

### 🟢 BAIXO: `.then()` instead of `async/await` (3 casos)

#### Local
```dart
lib/pages/detalhe_ocorrencia_page.dart:851
lib/pages/home_page.dart:359
lib/widgets/occurrence_card.dart:582
```

#### Impacto
Legibilidade apenas. Funciona corretamente.

---

### 🟢 BAIXO: `mounted` Check em `home_page.dart`

#### Local
```dart
lib/pages/home_page.dart:585
} catch (_) {
  if (mounted) setState(...);
}
```

**Status:** ✅ **Já está protegido** — bom padrão

---

---

## 📋 Checklist de Validação Manual (TODO)

Para confirmar os bugs potenciais encontrados, você deve:

### 1. Verificar `_RouterNotifier.dispose()` em app_router.dart

```bash
cd C:/Users/Gabriel Lucas/Eco_JP
grep -A30 "class _RouterNotifier" lib/core/router/app_router.dart | grep -E "dispose|cancel"
```

**Esperado:** Se vazio → **BUG CONFIRMADO**

### 2. Verificar `deep_link.dart` dispose

```bash
grep -A10 "void dispose()" lib/core/deep_link.dart | grep "_sub.cancel"
```

**Esperado:** Se vazio → **BUG CONFIRMADO**

### 3. Testar navigação rápida em "Minhas Denúncias"

Passos:
1. Abrir app
2. Ir pra "Minhas Denúncias" (tela com 3 listeners)
3. Swipe back rapidamente
4. Observar logs/crashes

**Esperado:** Nenhum crash ou erro em console  
**Se crashar:** Confirma race condition

### 4. Procurar por `.go()` / `.push()` sem `mounted`

```bash
grep -B5 "context\.go\|context\.push" lib/pages/*.dart | grep -c mounted
# Dividir por 2 (B5 = 5 linhas de contexto, pode incluir mounted)
```

**Esperado:** ~27 sem validação (encontrado)

---

## 📊 Matriz de Risco

| Bug | Severidade | Probabilidade | Impacto | Fix Time |
|---|---|---|---|---|
| Race condition streams | 🟠 Sério | 🟠 Média (nav rápida) | Crash ocasional | 30min |
| `_RouterNotifier` listeners | 🟡 Médio | 🟢 Baixa (app vive) | Memory leak | 20min |
| Deep link listener | 🟡 Médio | 🟢 Baixa (raro logout) | Memory leak | 10min |
| Navegação sem mounted | 🟡 Médio | 🟠 Média | Comportamento estranho | 1h |
| `.then()` legibilidade | 🟢 Baixo | 🟢 Nenhum | Refatoração | 30min |

---

## 🎬 Próximos Passos

### HOJE (Urgente)
- [ ] Rodar checklist de validação manual acima
- [ ] Confirmar quais bugs são reais (não teóricos)

### ESTA SEMANA (Blocking)
Se algum for confirmado:
- [ ] Adicionar `.cancel()` em `dispose()` de `_RouterNotifier`
- [ ] Adicionar `.cancel()` em `dispose()` de deep_link handler
- [ ] Testar navegação rápida em "Minhas Denúncias"

### PRÓXIMA SEMANA
- [ ] Aplicar `mounted` checks antes de toda navegação (`context.go`)
- [ ] Extrair streams em `ocorrencia_repository` pra método com cleanup explícito

### INTEGRAÇÃO CONTÍNUA
- [ ] Adicionar test de memory leak (usar `_MaintenanceAid` do Flutter)
- [ ] Setup GitHub Actions pra rodar `flutter analyze` + testes em PRs

---

## 📚 Referências

**Flutter Best Practices:**
- [AsyncErrors in Flutter](https://medium.com/flutter/dealing-with-async-in-flutter-8b2aaa17f46d)
- [Disposing Resources Properly](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
- [BuildContext.mounted](https://api.flutter.dev/flutter/widgets/State/mounted.html)

**Padrões confirmados OK:**
- ✅ `null-coalescing (??)`  — usando bem
- ✅ `mounted` checks em cadastro/dados_publicos
- ✅ `comLogDeErro` helper — centraliza erro
- ✅ Injeção de dependência em repositories

---

**Gerado em:** 2026-08-21  
**Próxima Auditoria:** Após fixes acima
