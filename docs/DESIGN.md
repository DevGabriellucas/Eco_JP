# Design — EcoJP

> Sistema visual e padrões de interface. A fonte da verdade em código é
> [`lib/theme/app_theme.dart`](../lib/theme/app_theme.dart); este arquivo explica as escolhas.

---

## 1. Princípios

1. **Confiança antes de tudo.** É um canal de denúncia com olhar de órgão público:
   visual limpo, sóbrio, sem ruído. O verde é de marca, não de enfeite.
2. **Rápido de usar na rua.** Uma mão, sol forte, sinal fraco: alto contraste, botões
   grandes, poucos passos.
3. **Status sempre legível.** O cidadão precisa entender num olhar em que pé está a denúncia.
4. **Claro e escuro de verdade.** Toda tela funciona nos dois temas.

## 2. Cores

### Marca e acento (iguais nos dois temas) — `AppColors`

| Token | Hex | Uso |
|---|---|---|
| `primary` | `#1F7A4D` | Marca, links, indicadores de progresso (claro) |
| `primaryLight` | `#43C589` | Marca no tema escuro |
| `primaryDark` | `#145A38` | Estados pressionados, ênfase |
| `success` | `#22C55E` | Feedback positivo |
| `successStrong` | `#16A34A` | Selos "verificado"/"resolvido", enviar, seguir |
| `warning` | `#F97316` | "Em análise", alertas, cor secundária do esquema |
| `danger` | `#EF4444` | Erros, ações destrutivas, "não confirmada" |
| `info` | `#2563EB` | Informativo |

### Neutros (mudam com o tema) — `AppPalette` via `context.pal`

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `background` | `#F4F6F3` | `#0E1311` | Fundo do scaffold |
| `surface` | `#FFFFFF` | `#171C19` | Cards, app bar, inputs |
| `surfaceAlt` | `#EDEDED` | `#1F2521` | Cards secundários, chips neutros |
| `ink` | `#1A1A1A` | `#ECEFEC` | Texto principal, botão primário |
| `muted` | `#6B7280` | `#A6AEA8` | Texto secundário |
| `hint` | `#8A8A8A` | `#8B938C` | Placeholders |
| `border` | `#D8DED6` | `#2B322D` | Divisórias e contornos |

### Paleta do Figma — `BrandColors` (`lib/theme/brand_colors.dart`)

Cores extraídas das telas do Figma, fixas (não mudam com o tema).

| Token | Hex | Uso |
|---|---|---|
| `brandDeep` | `#08382E` | Verde profundo de marca, fundo de destaque |
| `background` | `#1A2420` | Fundo de tela escuro |
| `accent` | `#52D5A0` | Botões primários, links, realces |
| `onAccent` | `#070C0A` | Texto e ícone sobre `accent` |
| `textPrimary` | `#F6F8F7` | Títulos, texto de campos e botões sobre fundo escuro |
| `textSecondary` | `#C7D0CB` | Subtítulos e texto de apoio |
| `textTertiary` | `#FFFFFF80` | Rodapés e legendas (branco 50%) |
| `primary` | `#087F5B` | Botão primário e links sobre fundo claro |
| `onPrimary` | `#FFFFFF` | Texto sobre `primary` |
| `surfaceLight` | `#FFFFFF` | Sheet / cartão claro |
| `primarySoft` | `#E8F3EE` | Fundo de ícone sobre claro |
| `textOnLight` | `#1A2420` | Títulos sobre claro |
| `textOnLightMuted` | `#5F6B66` | Texto de apoio sobre claro |
| `neutralSoft` | `#D3D9D6` | Indicador inativo, divisórias |
| `linkSecondary` | `#287894` | Links secundários sobre claro ("Esqueceu a senha?"); valor do Figma |

As sete últimas foram estimadas na imagem do onboarding (só `primary` saiu de um SVG do
Figma); confira no Figma.

**Regra:** telas usam `context.pal.<token>` para neutros, `AppColors.<token>` para acento
e `BrandColors.<token>` para a paleta do Figma. Nunca hex solto.

## 3. Tipografia

- **Poppins** em títulos (`display*`, `headline*`, `title*`) e botões — personalidade.
- **Inter** no corpo e rótulos (`body*`, `label*`) — legibilidade em tela pequena.
- Definidas no `TextTheme` central: um `Text` que só ajusta tamanho/peso herda a família.
- App bar: Poppins 18, peso 700, centralizado.

### Fontes do Figma — `BrandFonts` (`lib/theme/brand_fonts.dart`)

- **Inter** (`BrandFonts.sans`) para texto de interface e **IBM Plex Mono**
  (`BrandFonts.mono`) para números, códigos e rótulos técnicos.
- Pesos embutidos em `assets/fonts/`: 400 (`regular`), 500 (`medium`) e 600 (`semiBold`).
  Funcionam offline e não fazem requisição ao Google; outro peso é baixado da internet.
- Licenças (SIL OFL 1.1) em `assets/fonts/OFL-*.txt`, registradas na tela de licenças.
- Nada de `fontFamily` solto em tela: use `BrandFonts` ou o `TextTheme`.
- Estilos nomeados (variação por `copyWith`):

| Estilo | Fonte | Uso |
|---|---|---|
| `BrandFonts.tagline` | Plex Mono 500, 10, espaçamento 2,4 | Frase curta em caixa alta ("NATUREZA CONECTADA") |
| `BrandFonts.caption` | Plex Mono 400, 10, espaçamento 1,0 | Legendas (localização na splash) |
| `BrandFonts.heading` | Inter 600, 30, altura 1,3 | Título de tela (onboarding) |
| `BrandFonts.body` | Inter 400, 17, altura 1,5 | Texto corrido de apoio |
| `BrandFonts.label` | Inter 600, 16 | Botões e links |

  Os valores foram medidos na imagem do Figma, não lidos do arquivo; ajuste quando tiver os
  números exatos.

### Splash

`lib/pages/splash_page.dart`, fundo `BrandColors.brandDeep`. A splash nativa (Android e iOS)
é só essa cor, replicada em `android/app/src/main/res/values/colors.xml`
(`splash_background`) e em `ios/Runner/Base.lproj/LaunchScreen.storyboard`: mude os três
juntos.

## 4. Componentes

| Componente | Padrão |
|---|---|
| Botão primário (`ElevatedButton`) | Fundo `ink`, texto `surface`, altura 48, raio 12, Poppins 600 — inverte com o tema |
| Botão secundário (`OutlinedButton`) | Contorno `ink`, altura 48, raio 12 |
| Botão de texto | Cor `primary` |
| FAB | Fundo `ink`, ícone `surface` |
| Input | Preenchido com `surface`, raio 10, borda `border`; foco `ink` 1.5; erro `danger` |
| Snackbar | Flutuante, fundo `ink`, raio 10 |
| Card de denúncia (`widgets/occurrence_card.dart`) | Mídia, categoria, bairro, tempo relativo, selo de status, ações (curtir, comentar, compartilhar) |
| Estados de lista (`widgets/feed_states.dart`) | Vazio, carregando e erro com ação de tentar de novo |
| Aviso de recorte (`widgets/aviso_recorte.dart`) | Quando o limite de 500 registros foi atingido, mostra o total real |

### Ícones e ilustrações — `lib/theme/app_icons.dart`

| Pasta | Conteúdo | Acesso |
|---|---|---|
| `assets/icons/ui/` | Ícones de interface | `AppIcons.<nome>` |
| `assets/icons/illustrations/` | Ilustrações e padrões decorativos | `AppIllustrations.<nome>` |
| `assets/icons/logos/` | Logo do app e marcas de terceiros | `AppLogos.<nome>` |

Variantes por fundo: `AppLogos.ecohub` (fundo escuro) e `AppLogos.ecohubOnLight` (fundo
claro); `AppIllustrations.contourLines` (tela cheia, fundo escuro) e `contourLinesLight`
(recorte bege para fundo claro).

Arquivos em `snake_case`, sem sufixo `_icon`. Nunca escreva o caminho do asset na tela;
arquivo novo ganha constante em `app_icons.dart` (e entra na lista `todos`, que o teste
`test/theme/app_icons_test.dart` confere).

Raios: 10 (inputs, snackbar) e 12 (botões, cards). Elevação zero; separação por cor de
superfície e borda.

## 5. Status da denúncia

Cores definidas em `EstagioOficial.cor` (`lib/models/occurrence_types.dart`):

| Estágio | Cor |
|---|---|
| Pendente | cinza `#9CA3AF` |
| Em análise | `warning` |
| Confirmada | `success` |
| Encaminhada | azul `#3B82F6` |
| Resolvida | `successStrong` |
| Não confirmada | `danger` |

Status nunca depende só da cor: sempre há rótulo em texto. (Os hex soltos de pendente e
encaminhada são candidatos a virar token.)

## 6. Navegação

- Shell com abas inferiores: **Feed · Mapa · Dados · Perfil**, e FAB para nova denúncia.
- Transição `FadeForwards` (Material 3) em todas as plataformas.
- Autoridade vê entradas extras: fila de verificação, fila de moderação, painel de triagem.

## 7. Telas de referência

As capturas de tela saíram de `docs/`; as antigas continuam no histórico do git
(commit `158559d`, pasta `docs/img/`).

## 8. Acessibilidade

- Área de toque mínima 48 × 48 dp.
- Ícones interativos com `tooltip` ou `Semantics(label:)`.
- Contraste mínimo WCAG AA (4.5:1 para texto normal) nos dois temas.
- Não usar só cor para transmitir informação.
- Respeitar o tamanho de fonte do sistema (sem `textScaleFactor` fixo).

## 9. Pendências de design

- Dark mode ainda parcial em algumas telas.
- Revisão de UX/acessibilidade das telas principais (Fase 5 do ROADMAP).
