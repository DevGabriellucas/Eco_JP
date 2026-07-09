# EcoJP — Plano de Upgrade (jun → ago 2026)

> Documento de planejamento da evolução do EcoJP de protótipo acadêmico para
> aplicação de nível profissional, com segurança forte e conformidade legal,
> visando uso como projeto de extensão (UNIPE/UFPB) e possível adoção pelo
> Ministério Público da Paraíba (MPPB).

**Janela de trabalho:** 16/06/2026 → 10/08/2026 (~8 semanas)
**Meta:** ao voltar das férias (início de agosto), apresentar uma versão
visivelmente mais robusta, segura e madura.

---

## 1. Onde estamos hoje (base já construída)

O projeto **não parte do zero**. Auditoria de 16/06/2026 confirmou:

- **Regras de segurança do Firestore robustas** — validação por campo, controle
  de dono (owner), integridade de reações via transação, validação de
  comentários e notificações, e negação por padrão (`allow read, write: if false`).
- **Nenhum segredo vazado** no histórico do Git; `.gitignore` cobre
  `firebase_options.dart`, `google-services.json`, `.env`, `local.properties` e chaves.
- **Cloudinary** com *unsigned upload preset* (abordagem correta no cliente).
- **54 testes automatizados** passando; `flutter analyze` sem problemas.
- **CI no GitHub Actions** rodando análise + testes + formatação a cada push.

Ou seja: a fundação é sólida. Este plano é sobre **blindagem, conformidade e
maturidade institucional** — não sobre reescrever o que funciona.

---

## 2. Princípios que guiam o upgrade

1. **Segurança por padrão** — nada confia no cliente; tudo é validado no servidor.
2. **Conformidade com a LGPD** — requisito legal para qualquer coisa ligada ao MPPB.
3. **Sem regressão** — cada mudança entra com testes; CI verde é obrigatório.
4. **Rastreabilidade** — denúncias e mudanças de status têm histórico auditável.
5. **Incremental** — o app continua funcionando em todas as etapas.

---

## 3. Cronograma das 8 semanas

### 🔴 Fase 1 — Blindagem de segurança (Semanas 1–2 · 16–29 jun)

**Objetivo:** fechar o principal vetor de abuso antes de o projeto crescer.

- [x] Ativar **Firebase App Check** (Android + iOS) — impede que scripts externos
      usem a configuração pública do Firebase fora do app.
      *(Feito: Android com Play Integrity (prod) / debug provider (dev), iOS com
      AppleDebugProvider até ter conta Apple Developer. Imposição ativa no Firestore.)*
- [x] Exigir **verificação de e-mail** no cadastro antes de permitir denúncias.
      *(Feito: tela de confirmação + trava no `AuthCheck` + regras exigindo
      `email_verified` para postar. Publicado no Firebase.)*
- [x] Endurecer o **Cloudinary**: formatos permitidos restringidos no preset
      `Eco_JP` (`jpg,jpeg,png,webp,heic,mp4,mov,m4v`); limite de tamanho
      garantido no cliente (8 MB foto / 50 MB vídeo) — independente do painel,
      já que o plano gratuito não expõe limite de tamanho por preset.
      Moderação manual no painel avaliada e descartada (travaria a publicação
      imediata que o app depende).
- [x] Revisão final das regras do Firestore com App Check ativo.

**Por quê:** sem App Check, as regras seguram muita coisa, mas a porta dos fundos
fica aberta. Esta é a tranca que falta para "segurança contra vazamento".

---

### 🔴 Fase 2 — Conformidade LGPD (Semanas 3–4 · 30 jun – 13 jul)

**Objetivo:** tornar o app legalmente apto a tratar dados pessoais.

- [x] Tela de **consentimento** com registro comprovável (LGPD art. 8 §1):
      coleção `consentimentos/{uid}` com versão + carimbo de tempo. Trava de
      consentimento no `AuthCheck` pega contas Google e usuários anteriores à
      política; cadastro por e-mail grava o aceite do checkbox. Re-consentimento
      automático quando `kVersaoDocumentosLegais` muda. Links permanentes à
      política/termos no perfil + data do consentimento.
- [x] **Política de Privacidade** atualizada (`documentos_legais.dart`):
      cobre vídeo, IA (Gemini/Google), denúncia anônima, acesso de autoridades,
      App Check e retenção. *(Ainda requer revisão jurídica antes de publicar.)*
- [x] **Excluir conta** + apagar dados do usuário (inclui o registro de
      consentimento na exclusão).
- [x] **Exportar meus dados** (direito de portabilidade): botão no perfil gera
      um PDF com perfil, data de consentimento e as denúncias do usuário
      (pacote `printing`). *(Evolução futura: oferecer também JSON para
      portabilidade interoperável.)*
- [ ] Documentar quais dados são coletados, por quê e por quanto tempo.
- [x] **Proteção do denunciante**: opção de denúncia anônima no formulário —
      nome/foto nunca são gravados no documento (não é só ocultado na tela),
      vale também para autoridade. Comparado ao Radar Ambiental (app nacional
      do CNMP), este é um diferencial de segurança para quem teme retaliação.

**Por quê:** localização + foto + identidade são dados pessoais. Órgão público
no Brasil **exige** LGPD; sem isso, a adoção pelo MPPB não avança.

---

### 🟡 Fase 3 — Camada institucional (Semanas 5–6 · 14–27 jul)

**Objetivo:** dar credibilidade de órgão oficial ao app.

- [x] Papel de **autoridade** via coleção `roles` no Firestore (sem custom claims:
      concedido pelo Console, sem script nem Cloud Functions/Blaze).
- [x] Autoridade pode marcar denúncia como **verificada** (selo no feed e no
      detalhe), com auditoria (quem verificou + quando).
- [x] Ciclo oficial completo pela autoridade: pendente → em análise →
      confirmada → encaminhada → resolvida (+ não confirmada), com carimbo de
      tempo de auditoria (`verificadaEm`, `encaminhadaEm`, `resolvidaEm`) e
      fila de verificação ordenada por antiguidade.
- [ ] **Denunciar conteúdo abusivo** (texto/imagem) + fila de moderação.
- [x] Regras do Firestore atualizadas para reconhecer o papel de autoridade.
- [x] Aba "Dados" em dois níveis: cidadão vê gráficos gerais; autoridade vê
      também o painel de triagem (funil + tempos médios + taxas).
- [x] **Notificação ao cidadão** a cada avanço do status oficial (em análise,
      confirmada, encaminhada, resolvida, não confirmada) — antes só dava pra
      saber abrindo a denúncia de novo. Fecha gap identificado vs. Radar
      Ambiental (app nacional do CNMP), que já notifica andamento.
- [x] **Sugestão de categoria por IA** (Gemini 2.5 Flash via Firebase AI
      Logic, pacote `firebase_ai`) no formulário de denúncia — protegida pelo
      App Check já ativo, sem backend próprio. É só sugestão: o usuário
      sempre pode trocar a categoria antes de enviar.
      *(Pendente: habilitar a API no Console do Firebase — Build → AI Logic
      → Get started — antes de testar em produção; tier gratuito tem aviso de
      uso de prompts para treinamento, considerar tier pago se o MPPB adotar.)*

**Por quê:** é o que separa "rede social de reclamações" de "canal oficial".
O MPPB precisa enxergar um fluxo confiável de triagem.

---

### 🟡 Fase 4 — Observabilidade e custo (Semana 7 · 28 jul – 3 ago)

**Objetivo:** saber o que acontece em produção e reduzir custo de operação.

- [ ] **Firebase Crashlytics** (capturar erros reais dos usuários).
- [ ] **Firebase Analytics** (entender uso — denúncias por bairro, etc.).
- [ ] Corrigir `contarComentarios` (hoje lê todos os comentários só para contar).
- [ ] Corrigir `listarOcorrencias()` sem limite (lê a coleção inteira).

**Por quê:** em produção você precisa enxergar falhas e segurar o custo do
Firestore antes de escalar para milhares de usuários.

---

### 🟢 Fase 5 — Polimento e apresentação (Semana 8 · 4–10 ago)

**Objetivo:** entregar uma versão apresentável e estável.

- [ ] Revisão de UX/acessibilidade das telas principais.
- [ ] Ampliar cobertura de testes nas regras novas (moderação, LGPD).
- [ ] Atualizar `README.md` e `CONFIGURACAO.md`.
- [ ] Preparar roteiro de demonstração para UNIPE/UFPB/MPPB.

---

## 4. Definição de "pronto" (para cada item)

Um item só é considerado concluído quando:

1. Funciona no app (web e Android).
2. Tem teste automatizado quando aplicável.
3. `flutter analyze` limpo e CI verde.
4. Não introduz segredo no repositório.
5. Está documentado (no código e/ou neste roadmap).

---

## 5. Riscos e dependências

| Risco | Mitigação |
|---|---|
| App Check exige configuração no Console do Firebase | Fazer cedo (Fase 1) e testar em device real |
| LGPD pode exigir texto jurídico | Validar política com alguém da faculdade/jurídico |
| Custom claims exigem Cloud Functions ou script admin | Avaliar Cloud Functions na Fase 3 |
| Tempo curto (férias no meio) | Fases independentes — dá para reordenar sem travar |

---

## 6. Glossário (para leitores não técnicos)

- **App Check:** verifica que as requisições vêm do app de verdade, não de um robô.
- **LGPD:** Lei Geral de Proteção de Dados — regula o uso de dados pessoais no Brasil.
- **Custom claims:** etiqueta de permissão (ex.: "moderador") ligada à conta do usuário.
- **Firestore rules:** regras no servidor que decidem quem pode ler/escrever cada dado.
- **CI:** automação que testa o projeto a cada alteração, evitando quebrar o que funciona.

---

*Última atualização: 16/06/2026.*
