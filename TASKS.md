# Tarefas — EcoJP

> Lista de trabalho viva. Marque `[x]` ao concluir e mova para "Feito" no fim do ciclo.
> Prioridade: 🔴 bloqueia demo/LGPD · 🟡 importante · 🟢 melhoria.

**Atualizado em:** 01/10/2026

---

## 🔴 Agora — antes de qualquer apresentação

- [ ] Revisar e commitar a Sprint 1 (49 cards, em `Develop` sem commit) — commits separados por área; `dart format` à parte.
- [ ] Rodar `flutterfire configure` com o novo ID `br.com.ecojp.app` (`firebase_options.dart` ainda aponta para `com.example.ecoJp`).
- [ ] Atualizar restrição da chave do Maps (pacote + SHA-1) para o novo ID.
- [ ] Criar secrets de assinatura no GitHub: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- [ ] Cadastrar SHA-1/SHA-256 (upload + Play App Signing) no Firebase e no App Check.
- [ ] Implantar na ordem: app → índices → `backfill:oculto` (dry run e `--aplicar`) → regras.
- [ ] Revisão jurídica da política de privacidade + e-mail do DPO.

## 🔴 LGPD

- [ ] Exclusão de conta: anonimizar `userName`/`userPhotoUrl` nos comentários do usuário.
- [ ] Exclusão de conta: apagar mídia no Cloudinary (exige upload assinado + Cloud Function).
- [ ] Remoção de metadados no upload preset do Cloudinary (transformação).
- [ ] Documentar quais dados são coletados, por quê e por quanto tempo (Fase 2 do ROADMAP).
- [ ] Comentário do autor anônimo "como Autor da denúncia" (hoje só há aviso; exige mudar o modelo de comentário).

## 🟡 Configuração de plataforma

- [ ] App Check: registrar Android, iOS e web; chave reCAPTCHA v3 (`--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY`); App Attest no App ID da Apple; **depois** ligar a imposição.
- [ ] iOS: `GIDClientID` e `REVERSED_CLIENT_ID` no `Info.plist`.
- [ ] Chave do Maps de servidor separada para `tools/geocode_bairros.mjs`; chave web restrita por domínio em `web/index.html`.
- [ ] Corrigir `COMSPEC` do Windows (aponta para `C:\msys64\ucrt64\bin` e quebra `flutter.bat`).

## 🟡 Bugs relatados (testes manuais)

- [ ] Link de verificação de e-mail chega expirado; tela de verificação fecha sozinha.
- [ ] Ao curtir, o texto do comentário muda de forma.
- [ ] Emoji é enviado direto como comentário.
- [ ] Animação do coração de curtida aparece atrás do card.
- [ ] "Ver todos os N comentários" não faz nada.
- [ ] Abrir respostas de um comentário recarrega a página inteira.
- [ ] Curtidas de comentário como texto abaixo ("1 curtida").
- [ ] Tocar no card não abre o post em foco.
- [ ] Conferir e ajustar o compartilhamento.
- [ ] Coleta de lixo por bairro não funciona.
- [ ] Duas sessões simultâneas na mesma conta.
- [ ] "Usar localização atual" confirma, mas o campo mostra "Endereço não encontrado".
- [ ] "Endereço não encontrado" precisa ser apagado à mão no campo.
- [ ] Conquistas mal alinhadas na tela.

## 🟡 Escala e custo (dependem de `functions/`)

- [ ] Criar `functions/` em TypeScript (desbloqueia os itens abaixo).
- [ ] Reações fora do array do documento (subcoleção ou contador distribuído).
- [ ] Documento agregado para mapa, estatísticas e dados públicos (hoje leem até 500 docs).
- [ ] Mapa por viewport/geohash.
- [ ] Comprimir foto/vídeo no upload (~6× menos mídia).

## 🟢 Melhorias

- [ ] Atualizar `geolocator` (^9), `go_router` (^12) e `google_sign_in` (^6).
- [ ] Exportar dados também em JSON (portabilidade interoperável).
- [ ] Completar dark mode nas telas restantes.
- [ ] Revisão de UX/acessibilidade (Fase 5).
- [ ] Ampliar testes de regras de moderação e LGPD.
- [ ] Roteiro de demonstração para Unipê, MP e parceiros.
- [ ] Definir licença do repositório.

---

## ✅ Feito

- [x] Sprint 1 implementada em `Develop` (01/10/2026) — ver `docs/Sprint1-resumo.md`.
- [x] Reserva atômica de nome em `nomes_reservados`.
- [x] Novo ID `br.com.ecojp.app` e assinatura de release.
- [x] App Check ativado no app.
- [x] Suíte de carga k6 e CI na `Develop`.
- [x] ADR 0001: manter Firebase.
- [x] Consentimento com versão, exportar dados (PDF), excluir conta.
- [x] Papel de autoridade, ciclo oficial com auditoria, notificações de status.
- [x] Crashlytics e Analytics.
