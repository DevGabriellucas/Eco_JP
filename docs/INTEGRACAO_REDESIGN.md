# Guia — integrar os redesigns paralelos à Develop

> Para quem vai atualizar `feature/entrada-ecohub` e `feature/novo-feed` depois que a
> `refactor/login` entrar na `Develop`. Escrito em 11/10/2026.

## 1. Situação

As duas branches saíram de `d49ea1b`, **25 commits antes** da `Develop` atual (antes da
Sprint 1). A `refactor/login` refez as mesmas telas de entrada (splash, inicial, login,
cadastro, confirmação de e-mail, consentimento) e corrigiu bugs de roteamento que voltam
se o código antigo for trazido sem cuidado. Juntar como estão **quebra o app**, em parte só
em tempo de execução (o build passa e o problema aparece na tela).

| Arquivo / área | `entrada-ecohub` / `novo-feed` | `Develop` (com a `refactor/login`) |
|---|---|---|
| `login_page`, `cadastro_page`, `inicial_page` | redesign próprio | redesign do Figma ecohub, claro e escuro |
| Abertura do app | `LoadingScreen` + `_SplashScreen` no router | `SplashPage` + `inicializacaoProvider` + `EcoJpApp` |
| Splash nativa (`colors.xml`, `launch_background`, `styles` v31, `LaunchScreen.storyboard`) | alterada | só a cor `#08382E` |
| `lib/theme/app_theme.dart` | `AppColors` redefinido (`primary` `#099C5E`…), `AppSpacing`, `AppRadius` | registra `MarcaCores` (claro/escuro) |
| `AppIcons` | `lib/widgets/shared/app_icons.dart` → `IconData` (Cupertino) | `lib/theme/app_icons.dart` → caminhos de SVG (`String`) |
| `occurrence_card.dart`, `test/widgets/inicial_page_test.dart` | reescritos | alterados |

## 2. Passo a passo

1. `git fetch` e atualize a branch a partir da `Develop` (`git merge origin/Develop`, ou
   rebase se preferir). Faça a `entrada-ecohub` primeiro; a `novo-feed` foi feita em cima dela.
2. Resolva os conflitos nesta ordem: `pubspec.yaml` → `lib/theme/` → `lib/core/` (router,
   inicialização) → páginas → testes. Nas telas de entrada, **parta da versão da `Develop`** e
   traga só o que for novo de verdade (ver seções 5 e 6).
3. Resolva as colisões de nome (seção 4) e os caminhos de asset (seção 3).
4. Rode e só abra o PR com tudo verde:
   ```bash
   dart format lib test
   flutter analyze
   flutter test
   ```

## 3. Caminhos de asset (sempre pela constante)

A pasta `assets/icons/` foi dividida em `ui/`, `illustrations/` e `logos/`. **O `pubspec` não
declara mais `assets/icons/`** (o Flutter não inclui subpastas sozinho), então qualquer
caminho antigo compila, mas falha na tela.

| Antes | Agora |
|---|---|
| `assets/icons/google_icon.svg` | `AppLogos.google` |
| `assets/icons/seta.svg` | `AppIcons.arrowLeft` |
| `assets/icons/comment.png` | `AppIcons.comment` |
| `assets/icons/<nome>_icon.svg` | `AppIcons.<nome>` (`ui/<nome>.svg`) |
| `assets/icons/logo_ecohub.svg` | `AppLogos.ecohub` (fundo escuro) / `AppLogos.ecohubOnLight` (claro) |
| `assets/icons/*_ilustration.svg` | `AppIllustrations.*` |

Regra: **nunca escreva `'assets/...'` em tela**; use as constantes de
`lib/theme/app_icons.dart`. Arquivo novo ganha constante lá e entra na lista `todos` — o teste
`test/theme/app_icons_test.dart` carrega cada um e quebra se o caminho estiver errado.

Assets que já falham nas branches paralelas, mesmo sem juntar:

- `assets/ecohub_logo_draw.svg` e `assets/ecohub_logo_strokes.svg` estão na **raiz** de
  `assets/`, que não está no `pubspec`. Mova para `assets/icons/logos/` (já declarada) e
  crie as constantes.
- `assets/images/feed/*.png` está numa **subpasta** não declarada. Declare
  `- assets/images/feed/` no `pubspec`.

## 4. Nomes que colidem

Existem duas classes `AppIcons` com membros de mesmo nome e tipos diferentes (`trash`,
`camera`, `comment`: `IconData` num, `String` no outro). Um arquivo que importe as duas não
compila, e trocar o import dá erro de tipo.

**Renomeie a do feed** (ex.: `IconesCupertino` em `lib/widgets/shared/icones_cupertino.dart`)
e ajuste `occurrence_types.dart`, `home_page.dart` e o que mais a usar. No
`occurrence_card.dart` (alterado dos dois lados), o ícone de comentário da `Develop` é o PNG
`AppIcons.comment`; decida qual fica e use um só.

## 5. Abertura do app (splash) — o que não pode voltar

Mantenha o fluxo da `Develop`:

- `main.dart` chama `runApp` na hora; o Firebase sobe em `inicializacaoProvider`
  (`lib/core/inicializacao.dart`) com a `SplashPage` na tela. Tempo total =
  `max(3 s, inicialização)`.
- A rota `/splash` usa `SplashPage(animarEntrada: false)` — **não** recoloque um
  `_SplashScreen` com `CircularProgressIndicator`.
- Se a animação de escrita do logo (`LoadingScreen`, `ecohub_logo_drawing`) for mantida,
  coloque-a **dentro** da `SplashPage` (no lugar do logo estático), não como outra rota.
- A cor da splash nativa é cópia de `BrandColors.brandDeep` em
  `android/app/src/main/res/values/colors.xml` e no `LaunchScreen.storyboard`. Mude os três
  juntos, senão a tela "pisca" na abertura.

## 6. Roteamento — armadilhas já corrigidas

`lib/core/router/app_router.dart`:

- **O redirect enxerga a tela de baixo da pilha.** Com telas abertas por `push` (inicial →
  login → cadastro), `state.matchedLocation` é `/inicial`. Nenhuma regra pode depender de
  `loc == <rota aberta por push>`. Por isso a trava do cadastro é só o flag
  `cadastroEmAndamentoProvider` — com `loc == /cadastro` o app pulava para a confirmação no
  meio do cadastro e, com nome em uso, apagava a conta por trás.
- **Recarga não vai para a splash.** Estado recarregando (já tinha valor) fica na tela
  atual (`_aguardar`); só "sem valor nenhum" (abertura) vai para `/splash`.
- Testes que pegam as duas: `test/core/fluxo_cadastro_router_test.dart` e
  `test/core/app_router_test.dart`. Se falharem depois do merge, a regressão voltou.

## 7. Tema

- Telas de entrada e componentes de `lib/widgets/marca/` leem `context.marca`
  (`lib/theme/marca_cores.dart`), que troca com o tema claro/escuro. **Não use
  `BrandColors` direto** para fundo, texto, borda ou destaque nessas telas.
- Use os componentes prontos (`CampoMarca`, `BotaoPrimario`, `BotaoSecundario`,
  `AceiteTermos`, `CorpoRolavel`…) — ver `docs/DESIGN.md`.
- A `novo-feed` redefine `AppColors` (outros verdes, laranja, vermelho). Isso muda a cor do
  app inteiro, não só do feed: combine os valores e registre no `DESIGN.md` antes de juntar.

## 8. Checklist antes do PR para a Develop

- [ ] Branch atualizada a partir da `Develop`, sem marcadores de conflito.
- [ ] Nenhum caminho de `assets/icons/` escrito à mão: `git grep "'assets/icons/" lib` só
      pode encontrar `lib/theme/app_icons.dart`.
- [ ] Assets novos com constante, na lista `todos` e com a pasta declarada no `pubspec`.
- [ ] Um único `AppIcons` (o de caminhos); o de `IconData` renomeado.
- [ ] Uma única splash (`SplashPage`); nada de `_SplashScreen` no router.
- [ ] `fluxo_cadastro_router_test` e `app_router_test` passando.
- [ ] Telas de entrada conferidas nos modos claro e escuro.
- [ ] `dart format`, `flutter analyze` e `flutter test` limpos.
