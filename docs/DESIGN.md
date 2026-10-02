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

**Regra:** telas usam `context.pal.<token>` para neutros e `AppColors.<token>` para acento.
Nunca hex solto.

## 3. Tipografia

- **Poppins** em títulos (`display*`, `headline*`, `title*`) e botões — personalidade.
- **Inter** no corpo e rótulos (`body*`, `label*`) — legibilidade em tela pequena.
- Definidas no `TextTheme` central: um `Text` que só ajusta tamanho/peso herda a família.
- App bar: Poppins 18, peso 700, centralizado.

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
