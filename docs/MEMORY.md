# Memória do projeto — EcoJP

> Decisões, contexto e armadilhas que **não** são óbvias lendo o código.
> Para pessoas novas no time e para agentes de IA. Uma entrada por fato, com data e o porquê.
> Não repita aqui o que já está no código, no git ou nos outros docs.

---

## Contexto

- **09/09/2026 — O projeto virou candidatura institucional.** Edital de inovação (CSED
  2026), Ministério Público e reitoria do Unipê. *Por quê importa:* "robusto" passou a
  significar LGPD auditável, demo sem falha e documentação, não aguentar milhares de
  usuários simultâneos.
- **O MP fiscaliza a LGPD.** Uma promessa da política de privacidade que o código não
  cumpre é o pior tipo de bug deste projeto.

## Decisões

- **10/09/2026 — Fica no Firebase** (ADR 0001). O argumento decisivo é offline: denúncia
  acontece na rua sem sinal, e o Firestore dá fila de escrita e cache de graça. O Blaze não
  tem piso (mesma cota grátis do Spark). Antes de reabrir a discussão, ver os gatilhos no
  fim do ADR (saiu de `docs/`; está no git, commit `158559d`). Se o objetivo for só SQL, export para BigQuery resolve sem mover o app.
- **Papel de autoridade pela coleção `roles`, não por custom claims** — dispensa Cloud
  Functions e é concedido pelo Console.
- **Anonimato vale perante a comunidade, não perante o órgão.** Está no item 3 da política
  (`documentos_legais.dart`). Não é lacuna.
- **`lib/firebase_options.dart` é versionado de propósito.** Config de app cliente não é
  segredo; a proteção está nas Rules e no App Check.
- **Cloudinary com upload unsigned** é a abordagem correta no cliente; a consequência é
  que apagar mídia na exclusão de conta exige Cloud Function.

## Escala e custo (auditoria 10/09/2026)

- O teto é **por documento**, não por usuário: curtidas em arrays no doc da ocorrência
  saturam em ~1/s e reenviam o doc inteiro para todo feed aberto.
- O app sai da cota grátis com ~50 usuários ativos/dia por causa do padrão de leitura
  (telas que baixam 500 docs). Com doc agregado + cursor cai de ~1.000 para ~60
  leituras/usuário/dia.
- O custo dominante é **mídia**, não banco. Comprimir no upload é o que mantém o piloto grátis.
- Tudo isso depende de criar `functions/`.

## Armadilhas

- **Ordem de implantação das regras:** app → índices → backfill → regras. As regras novas
  quebram versões antigas do app. Pular o backfill de `oculto` faz denúncias antigas sumirem.
- **Troca de ID para `br.com.ecojp.app`** exige `flutterfire configure` e atualizar
  restrições da chave do Maps e SHA-1 no Cloud Console. Sem isso, mapa e login quebram.
- **Release local** falha sem `android/key.properties`; para teste use
  `ECOJP_PERMITIR_RELEASE_DEBUG=true`.
- **Nome público:** rodar `npm run backfill:nomes` antes de publicar a reserva atômica,
  senão contas antigas ficam sem reserva.
- **Máquina de desenvolvimento (Windows):** `COMSPEC` aponta para o MSYS2 e quebra
  `flutter.bat` e `firebase emulators:exec`. Corrigir nas variáveis de ambiente.
- **ROADMAP.md está defasado** em alguns itens; na dúvida, o código e
  [TASKS.md](TASKS.md) valem mais.

- **02/10/2026 — Uma sessão por conta.** O último login derruba os outros aparelhos
  (`meta/sessao`). *Por quê:* a mesma conta era usada por duas pessoas ao mesmo tempo. O
  documento guarda só o id, sem data nem aparelho, para não virar log de acesso, que a
  política não prevê. Efeito colateral: conta de órgão compartilhada entre servidores se
  derruba sozinha.
- **Link de verificação "expirado":** suspeita (não confirmada) de restrição "Apps Android"
  na chave de API do Android; a página de confirmação do Firebase usa essa chave no
  navegador.

## Estado atual (02/10/2026)

- Sprint 1 commitada (`52cf0da`); índices, backfill `oculto` e regras publicados.
- Correções dos bugs dos testes manuais e sessão única commitadas em `Develop` (02/10/2026).
- Pendências de Console listadas em [TASKS.md](TASKS.md).

## Onde está o resto

- Produto: [PRD.md](PRD.md) · Arquitetura: [ARCHITECTURE.md](ARCHITECTURE.md) ·
  Regras: [RULES.md](RULES.md) · Design: [DESIGN.md](DESIGN.md) · Tarefas: [TASKS.md](TASKS.md)
- Decisões formais (ADR) e resumo da Sprint 1: histórico do git, commit `158559d`.
