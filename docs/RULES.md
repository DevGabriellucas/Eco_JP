# Regras do projeto — EcoJP

> Regras que toda pessoa (ou agente de IA) que mexe no código deve seguir.
> Se uma regra atrapalhar, discuta e mude este arquivo; não a ignore em silêncio.

---

## 1. Inegociáveis

1. **Nunca confie no cliente.** Toda regra de negócio que protege dados precisa estar nas
   `firestore.rules`. Validação no app é só conveniência de UX.
2. **Nenhum segredo no repositório.** Chave do Maps em `android/local.properties`,
   assinatura em `android/key.properties`, nada de `.env` ou `google-services.json` no git.
   `lib/firebase_options.dart` é exceção consciente (config pública).
3. **LGPD primeiro.** Nenhum dado pessoal novo é coletado sem atualizar a política em
   `lib/pages/legal/documentos_legais.dart` e subir `kVersaoDocumentosLegais`.
4. **Denúncia anônima não grava identidade no documento público.** Nem UID, nem nome, nem
   foto, nem coordenada exata.
5. **Mídia sai sem metadados.** Toda foto/vídeo passa por `utils/imagem_privacidade.dart`
   ou `utils/video_privacidade.dart` antes do upload.
6. **CI verde para entrar.** `flutter analyze` limpo, `dart format` aplicado, testes Dart e
   de regras passando.

## 2. Git

- Branches: `main` (estável, o que é apresentado), `Develop` (integração),
  `feature/<nome-curto>` a partir de `Develop`.
- Merge em `main` só a partir de `Develop`, com CI verde.
- Commits no padrão Conventional Commits, em português:
  `feat(escopo): ...`, `fix: ...`, `docs: ...`, `chore: ...`, `build: ...`, `test: ...`.
- Um commit, um assunto. Formatação mecânica (`dart format`) em commit separado.
- Nunca `push --force` em `main` ou `Develop` sem combinar com o time.

## 3. Código Dart/Flutter

- Siga `analysis_options.yaml` (`flutter_lints`). Zero warnings.
- Nomes de domínio em **português** (`ocorrencia`, `comentario`, `usuario`), igual ao
  Firestore. Termos técnicos do Flutter ficam em inglês.
- Arquivos em `snake_case.dart`; classes em `PascalCase`; um widget público por arquivo
  quando ele é usado fora da tela.
- Telas não acessam o Firestore direto: use `data/repositories/` ou `services/`.
- Estado com Riverpod. **Não crie streams/futures dentro do `build`**; exponha via provider.
- Rotas só por `Routes.*` (`lib/core/router/routes.dart`), nunca string literal.
- Cores e tipografia só por `AppColors`, `context.pal` e `Theme.of(context).textTheme`.
  Nada de `Color(0xFF...)` solto em tela (ver [DESIGN.md](DESIGN.md)).
- Erros: registre com `utils/log_erros.dart` / Crashlytics e mostre mensagem amigável via
  `utils/mensagem_erro.dart`. Nunca mostre exceção crua ao usuário.
- Comentários explicam **por quê**, não o quê.

## 4. Firestore

- Toda coleção nova precisa de bloco `match` explícito nas Rules **e** de testes em
  `test/firestore_rules/`. O resto cai no `allow read, write: if false`.
- Consultas de listagem sempre com `limit` e filtro `oculto == false`.
- Prefira `get()` paginado com cursor a listener ao vivo com `limit` crescente.
- Escritas relacionadas (denúncia + dono, status + histórico) vão no mesmo `batch`.
- Índice novo vai em `firestore.indexes.json` no mesmo PR.
- Mudança de regra incompatível segue a ordem de implantação de
  [ARCHITECTURE.md](ARCHITECTURE.md#8-implantação).

## 5. Testes

- Bug corrigido ganha teste que falharia antes da correção.
- Regra nova nas Rules: pelo menos um caso que permite e um que nega.
- Models: teste de `fromMap`/`toMap` com campos ausentes.
- Mocks: `fake_cloud_firestore` e `firebase_auth_mocks`; nada de bater no Firebase real.

## 6. Texto e UX

- Toda string visível em português do Brasil, tom direto e respeitoso.
- Mensagens de erro dizem o que aconteceu e o que fazer.
- Área de toque mínima de 48 dp; ícones com `tooltip`/`semanticLabel`.

## 7. Agentes de IA

- Leia [MEMORY.md](MEMORY.md) e [TASKS.md](TASKS.md) antes de começar.
- Não faça commit, push, deploy ou escrita em serviço externo (Trello, Firebase Console)
  sem aprovação explícita.
- Atualize [TASKS.md](TASKS.md) e [MEMORY.md](MEMORY.md) quando terminar algo relevante.
