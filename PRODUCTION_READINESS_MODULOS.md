# PRODUCTION READINESS — ETAPA 17.2: REVISÃO DE MÓDULOS
**EcoJP** — Auditoria técnica módulo a módulo

Realizada: 13 de julho de 2026
Baseada em leitura direta do código-fonte (arquivo:linha citados sempre que possível).

---

## Resumo de Notas e Prioridades

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

---

## 1. Auth
**Arquivos:** `auth_service.dart` (338) · `login_page.dart` (575) · `cadastro_page.dart` (607) · `verificacao_email_page.dart` (241) · `features/auth/providers/auth_providers.dart` (39)

### Problemas
- `cadastro_page.dart:24` — `UsuarioService()` instanciado direto, quebrando a consistência com o resto da página (que usa `ref.read` para Auth/Consent).
- `auth_service.dart` (várias linhas) — catch genérico expõe `e.toString()` cru em alguns pontos.
- `cadastro_page.dart:139-169` — rollback frágil: se checagem de nome duplicado falhar por rede após conta já criada no Auth, pode deixar conta "órfã" sem perfil no Firestore.
- Duplicação de UI quase 100% entre `login_page.dart` e `cadastro_page.dart` (inputs, labels, decorações, gradiente).

### Pontos positivos
- **Único módulo com adoção completa e real do Riverpod** (providers usados de ponta a ponta, incluindo redirect do GoRouter).
- Mapeamento de erros do Firebase Auth para pt-BR é excelente e cobre casos reais.
- Fluxo de verificação de e-mail com polling + cooldown bem pensado.
- Medidor de força de senha client-side.

**Nota: 8/10 · Prioridade: Baixa**

---

## 2. Home / Feed
**Arquivos:** `home_page.dart` (983) · `home_shell.dart` (255)

### Problemas
- 5 services instanciados direto (linhas 35-40), nenhum via Riverpod.
- **Violação de camada** — `home_page.dart:152`: chamada direta `FirebaseFirestore.instance.collection('usuarios')...` dentro da page, deveria estar em `UsuarioService`.
- Lógica de resolução de autor (`_carregarDadosAutor`, 138-174) **duplicada quase byte-a-byte** em `detalhe_ocorrencia_page.dart:_fetchAuthorData`.
- 3 `StreamBuilder` aninhados (518-547) só para montar o feed — padrão repetido em Perfil.
- Catch genérico em `_denunciarOcorrencia` (270-295) sem log da causa real.

### Pontos positivos
- Paginação incremental bem feita + cache de streams de comentário.
- `home_shell.dart` com `IndexedStack` lazy-loading de abas — bem pensado.

**Nota: 6/10 · Prioridade: Alta**

---

## 3. Mapa
**Arquivos:** `map_page.dart` (167) + `controller/` (438) + 8 widgets (~1500 linhas)

### Problemas
- `mapdisplay.dart:20` — `LocationService()` duplicado (já existe instância no controller).
- Carrega até `tetoAgregado` (500) ocorrências em memória e refiltra tudo client-side a cada toggle — funciona hoje, não escala linearmente.
- Lógica de câmera (auto-enquadrar) dentro do `build()` via `addPostFrameCallback` inline — funciona mas frágil de auditar.

### Pontos positivos
- **Melhor separação arquitetural do app**: `MapController extends ChangeNotifier` isola estado; views são "burras".
- Estados selados (`Loading`/`Init`/`Loaded`/`Error`) com tela de erro dedicada.
- Cálculo de zonas afetadas isolado e testável (`CalcMostAffectedZones`).

**Nota: 8/10 · Prioridade: Baixa**

---

## 4. Denúncias (Ocorrências)
**Arquivos:** `ocorrencia_service.dart` (152, fachada) · `form_ocorrencia_page.dart` (1482) · `detalhe_ocorrencia_page.dart` (1516) · `ocorrencia_repository.dart` (601) · `ocorrencia_model.dart` (177)

### Problemas
- **Violação de camada** — `detalhe_ocorrencia_page.dart:236-239`: mesma chamada Firestore direta do item 2.
- Duplicação de `_fetchAuthorData` (idêntica a Home).
- `form_ocorrencia_page.dart` — 96% do arquivo é uma única classe `_FormOcorrenciaPageState` com 6 services diretos; mistura fotos, vídeo, geocoding, IA e envio na mesma classe (SRP).
- `ocorrencia_repository.dart:511-530` (`listarParaVerificacao`) — **sem `.limit()`**, ao contrário dos outros endpoints de feed. Risco de escala em quem cresce primeiro: Fila de Verificação.
- `cadastrarOcorrencia` (44-81) — sem rollback se falhar gravação de ponteiro de denúncia anônima após doc principal já criado.
- Mostra `e.toString()` cru para exceções não mapeadas em alguns pontos.

### Pontos positivos
- **Melhor exemplo de arquitetura em camadas do projeto** — repository isola 100% do Firestore, testável com `fake_cloud_firestore`.
- `listarFeedComFixadas` resolve elegantemente "feed + fixadas" com merge determinístico.
- Proteção de denunciante anônimo bem implementada e documentada.
- Transações corretas para like/dislike mutuamente exclusivos.
- Rate limiting client-side com defesa em profundidade reconhecida.

**Nota: 7/10 · Prioridade: Alta**

---

## 5. Perfil
**Arquivos:** `perfil_page.dart` (963) · `editar_perfil_page.dart` (389) · `perfil_publico_page.dart` (562)

### Problemas
- 4 services diretos em `perfil_page.dart` (34-37); 3 diretos em `perfil_publico_page.dart` mesmo sendo `StatelessWidget` não-const (recriados a cada rebuild do pai).
- **3º/4º lugar** com padrão `StreamBuilder` aninhado (perfil_page duas vezes + perfil_publico_page).
- `perfil_page.dart` — 963 linhas dominadas por uma State grande (cálculo de stats + abas + ações + composição visual).
- `editar_perfil_page.dart` não valida nome único (`nomeEmUso`) ao editar — inconsistente com o cadastro, que valida.

### Pontos positivos
- Separação correta entre "meu perfil" (com abas/ações) e "perfil público" (somente leitura + seguir).
- Uso consistente do mecanismo de favoritos entre Home e Perfil.

**Nota: 6/10 · Prioridade: Média**

---

## 6. Admin (Fila de Verificação + Moderação)
**Arquivos:** `fila_verificacao_page.dart` (333) · `fila_moderacao_page.dart` (411) · `moderacao_service.dart` (136) · `role_service.dart` (31)

### Problemas
- `role_service.dart` sem cache/observação combinada — **5+ telas fazem sua própria chamada independente** de `isAutoridade`/`observarAutoridade` (Home, HomeShell, Detalhe, Perfil, Estatísticas). Ineficiência estrutural.
- `moderacao_service.dart:listarPendentes` (84-94) — sem `.limit()`, mesmo risco de escala do item 4.
- Sem paginação nas duas filas — tudo carregado de uma vez via `snapshots()`.
- Sem teste automatizado para `role_service.dart`.

### Pontos positivos
- `role_service.dart` minimalista e correto (só lê, nunca escreve — concessão de privilégio só via Console).
- `fila_moderacao_page.dart` espelha conscientemente `fila_verificacao_page.dart` (duplicação documentada e aceitável).
- `moderacao_service.dart` delega corretamente ocultação de conteúdo ao `OcorrenciaService`.
- Auditoria de quem/quando resolveu denúncia de moderação gravada.

**Nota: 6.5/10 · Prioridade: Média**

---

## 7. Configurações
**Arquivo:** `configuracoes_conta_page.dart` (431)

### Problemas
- 5 services diretos (33-37).
- `_confirmarExclusaoConta` (176-208) — **catch silencioso reconhecido no próprio comentário**: se `excluirTodosDados` falhar após a conta Auth já ter sido excluída, dados podem ficar órfãos no Firestore sem log/retry/alerta. **Implicação real de LGPD** (usuário acredita que dados foram apagados).

### Pontos positivos
- Fluxo de exclusão trata corretamente `requires-recent-login` com reautenticação.
- Exportação de dados (LGPD art. 18) implementada com feedback de erro.
- Boa separação visual da "zona de perigo".
- Nenhuma chamada Firestore direta — respeita a camada de serviço.

**Nota: 7.5/10 · Prioridade: Alta (compliance)**

---

## 8. Notificações
**Arquivos:** `notificacoes_page.dart` (292) · `notificacao_service.dart` (72)

### Problemas
- 3 services diretos (19-21).
- `contarNaoLidas` (52-57) usa `.snapshots().map((s) => s.docs.length)` — baixa **todos os docs** só pra contar, ao invés de aggregation query `.count()` (já usada em `contarComentarios`). Inconsistência de padrão dentro do próprio projeto.
- Lista completa limitada a 50 fixos, sem paginação real.

### Pontos positivos
- Módulo pequeno, coeso, melhor exemplo de "tamanho adequado à responsabilidade".
- Agrupamento por data limpo, sem lógica de negócio vazando pros widgets.
- Mapeamento tipo→ícone/cor centralizado em função pura.
- `marcarTodasComoLidas` usa `batch.commit()` corretamente.

**Nota: 7.5/10 · Prioridade: Baixa**

---

## 9. Favoritos
**Localização:** `usuario_service.dart:49-84`, consumido em Home e Perfil

### Problemas
- Não é módulo isolado — mistura com perfil/social graph/LGPD dentro de `UsuarioService` (nome do serviço não reflete todas as responsabilidades).
- `observarFavoritosIds` sem `.limit()`.
- Sem tratamento de erro explícito — falha de rede/permissão vira lista vazia silenciosa (`favSnap.data ?? const <String>{}` mascara o erro).

### Pontos positivos
- API simétrica e limpa (`salvarFavorito`/`removerFavorito`/`definirFavorito`).
- Uso consistente entre Home e Perfil, sem duplicação de regra.
- Particionamento em lotes de 30 para respeitar limite do `whereIn` do Firestore.

**Nota: 7/10 · Prioridade: Baixa**

---

## 10. Estatísticas
**Arquivo:** `estatisticas_page.dart` (1483 linhas, 21 classes)

### Problemas
- 4 services diretos (63-66).
- Arquivo maior do projeto, mistura 3 preocupações: cálculo de métricas, widgets de card, `CustomPainter`s de gráfico — candidatos a 3 arquivos separados.
- Agregação 100% client-side sobre até 500 documentos a cada rebuild — sem cache nem agregação de backend.
- Restrição de acesso por role só na UI (correto desde que Firestore Rules garantam o resto — não verificado neste escopo).

### Pontos positivos
- Funções de agregação são puras e isoláveis, testáveis sem widget test mesmo estando no mesmo arquivo.
- Gráficos customizados via `CustomPainter`, sem dependência pesada de terceiros.
- Exportação de relatório com loading state e feedback de erro.
- Reaproveita `tetoAgregado` compartilhado com o Mapa.

**Nota: 6.5/10 · Prioridade: Média**

---

## Achados Transversais (padrões repetidos em quase todos os módulos)

### 1. Migração Riverpod pela metade
Existem providers prontos (`ocorrenciaRepositoryProvider`, `comentarioRepositoryProvider`, `geocodingServiceProvider` em `lib/features/denuncias/providers/`) que **não são consumidos em nenhuma page** — confirmado via busca global. Zero `ref.watch`/`ref.read` desses três fora de si mesmos. Adoção real do Riverpod existe só no módulo Auth.

Arquivos que instanciam services direto (candidatos a usar `authServiceProvider` etc.):
`detalhe_ocorrencia_page.dart:50,52` · `estatisticas_page.dart:65` · `home_page.dart:36,39` · `home_shell.dart:30` · `form_ocorrencia_page.dart:47,48` · `perfil_publico_page.dart:24,26` · `configuracoes_conta_page.dart:33,34` · `editar_perfil_page.dart:36` · `perfil_page.dart:34,35` · `notificacoes_page.dart:19`

**Decisão necessária:** ou remove os providers não usados (código morto que confunde) ou migra de fato as pages para consumi-los.

### 2. Duplicação de resolução de autor
`home_page.dart:_carregarDadosAutor` ≈ `detalhe_ocorrencia_page.dart:_fetchAuthorData` (mesmo fallback nome→email→"Usuário"). Candidato a serviço/util único.

### 3. Duas violações diretas de camada
`home_page.dart:152` e `detalhe_ocorrencia_page.dart:236` chamam `FirebaseFirestore.instance` fora de service/repository.

### 4. StreamBuilder aninhado (2-3 níveis) repetido
Em `home_page.dart`, `perfil_page.dart` (2x) e `perfil_publico_page.dart`. Candidato a generalizar o combinador que já existe em `OcorrenciaRepository`.

### 5. Ausência de `.limit()`/paginação em 3 streams administrativos
`ocorrencia_repository.dart:listarParaVerificacao`, `moderacao_service.dart:listarPendentes`, `usuario_service.dart:observarFavoritosIds`. Baixo risco hoje, risco real em 6-12 meses de crescimento.

### 6. Verificação de papel (`isAutoridade`) repetida em 5+ telas
Cada uma com sua própria chamada independente ao `RoleService`. Candidato a provider de sessão único e compartilhado.

---

## Recomendação de Ordem de Ataque (ETAPA 17.3)

Sem reescrever nada do zero, nesta ordem:

1. **Corrigir as 2 violações de camada** (`home_page.dart:152`, `detalhe_ocorrencia_page.dart:236`) e **extrair a duplicação de resolução de autor** — baixo esforço, alto tráfego (Home + Denúncias).
2. **Logging/telemetria no catch silencioso de `excluirTodosDados`** (Configurações) — implicação legal, prioridade por compliance, não por volume de código.
3. **Adicionar `.limit()`** às 3 queries administrativas sem teto, antes que o volume de denúncias cresça.
4. **Decidir o destino dos providers Riverpod não utilizados** — remover ou migrar de verdade, mas não deixar como está (confunde arquitetura).
