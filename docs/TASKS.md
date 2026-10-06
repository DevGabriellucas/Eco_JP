# Tarefas — EcoJP

> Lista de trabalho viva. Marque `[x]` ao concluir e mova para "Feito" no fim do ciclo.
> Prioridade: 🔴 bloqueia demo/LGPD · 🟡 importante · 🟢 melhoria.

**Atualizado em:** 06/10/2026

---

## 🔴 Agora — antes de qualquer apresentação

- [ ] Publicar regras e índices da análise de 06/10: `firebase deploy --only firestore:rules,firestore:indexes` (o índice de grupo `comentarios.userId` é exigido pela exclusão de conta).
- [ ] iOS: rodar `flutterfire configure` para o bundle `br.com.ecojp.app` (`firebase_options.dart` ainda tem `iosBundleId: com.example.ecoJp`). O Android voltou a `com.example.eco_jp` (8cccfa9) e está coerente.
- [ ] Atualizar restrição da chave do Maps (pacote + SHA-1) para o novo ID.
- [ ] Criar secrets de assinatura no GitHub: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- [ ] Cadastrar SHA-1/SHA-256 (upload + Play App Signing) no Firebase e no App Check.
- [ ] Revisão jurídica da política de privacidade + e-mail do DPO.

## 🔴 LGPD

- [x] Exclusão de conta: anonimizar `userName`/`userPhotoUrl` nos comentários do usuário ("Usuário removido"; regra `isAnonimizacaoDoAutor`). Vale após publicar as regras.
- [ ] Exclusão de conta: notificações que o usuário enviou continuam com `deUsuarioNome` na caixa de quem recebeu, e `denuncias_moderacao` guarda `denuncianteId`. Exige Cloud Function.
- [ ] Exclusão de conta: apagar mídia no Cloudinary (exige upload assinado + Cloud Function).
- [ ] Remoção de metadados no upload preset do Cloudinary (transformação).
- [ ] Documentar quais dados são coletados, por quê e por quanto tempo (Fase 2 do ROADMAP).
- [ ] Comentário do autor anônimo "como Autor da denúncia" (hoje só há aviso; exige mudar o modelo de comentário).

## 🟡 Configuração de plataforma

- [ ] App Check: registrar Android, iOS e web; chave reCAPTCHA v3 (`--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY`); App Attest no App ID da Apple; **depois** ligar a imposição.
- [ ] iOS: `GIDClientID` e `REVERSED_CLIENT_ID` no `Info.plist`.
- [ ] Chave do Maps de servidor separada para `tools/geocode_bairros.mjs`.
- [ ] Corrigir `COMSPEC` do Windows (aponta para `C:\msys64\ucrt64\bin` e quebra `flutter.bat`).

## 🟡 Bugs relatados (testes manuais)

Corrigidos em `Develop` em 02/10/2026 (lista original em `docs/Erro q precisa se consertando .txt`):

- [x] Ao curtir, o texto do comentário muda de forma (coração com largura fixa).
- [x] Emoji é enviado direto como comentário (agora entra no campo, no cursor).
- [x] Animação do coração de curtida aparece atrás do card (ripple desenhado no Material de trás).
- [x] Comentários de código em inglês no painel de comentários.
- [x] "Ver todos os N comentários" não faz nada.
- [x] Curtidas de comentário como texto abaixo ("1 curtida").
- [x] Abrir respostas de um comentário recarrega a página inteira (estado por fio).
- [x] Conferir e ajustar o compartilhamento (acentos, ordem do texto, origem no iPad).
- [x] Tocar no card não abre o post em foco.
- [x] Duas sessões simultâneas na mesma conta (sessão única).
- [x] "Usar localização atual" confirma, mas o campo mostra "Endereço não encontrado".
- [x] "Endereço não encontrado" precisa ser apagado à mão (botão "x" no campo).
- [x] Conquistas mal alinhadas na tela (grade de colunas iguais).
- [x] Coleta de lixo por bairro não funciona: causa (asset fora do pubspec) já corrigida na Sprint 1; conferido de novo.
- [ ] Link de verificação de e-mail chega expirado: o app agora confere ao voltar do e-mail e avisa que reenviar invalida o link anterior. **Falta conferir no Console** se a chave de API do Android tem restrição "Apps Android" — a página de confirmação do Firebase usa essa chave no navegador e, com essa restrição, mostra "link expirado". "Tela fecha sozinha" não foi reproduzido.
- [x] Regras publicadas em `ecojp-8b952` (02/10/2026), incluindo as da Sprint 1 e a da sessão única.
- [x] Mapa bege, só com o logo do Google: resolvido com a volta do `applicationId` para `com.example.eco_jp` (8cccfa9); o APK de 05/10 abriu o mapa. Volta a valer quando o ID mudar.
- [ ] Botão "minha localização" do mapa (canto inferior esquerdo) fica em cima do logo do Google.

## 🟡 Escala e custo (dependem de `functions/`)

- [ ] Criar `functions/` em TypeScript (desbloqueia os itens abaixo).
- [ ] Reações fora do array do documento (subcoleção ou contador distribuído).
- [ ] Documento agregado para mapa, estatísticas e dados públicos (hoje leem até 500 docs).
- [ ] Mapa por viewport/geohash.
- [ ] Comprimir vídeo no upload (a foto já sai em 1600 px / qualidade 80; o vídeo sobe até 50 MB).
- [ ] `nomes_reservados`: no máximo uma reserva por conta (hoje ilimitada, ver comentário nas regras).
- [ ] Notificações geradas no servidor (hoje cliente→cliente).

## 🟡 Arquitetura (análise de 06/10)

- [ ] Services e repositories só por provider: tirar os `XService()` criados nas telas (27 em 12 arquivos) e injetar `FirebaseFirestore` pelo construtor, como já faz `OcorrenciaRepository`.
- [ ] Estado do feed num `Notifier` (paginação, filtros e cache de contagem saem do `home_page`).
- [ ] Agregação de `estatisticas_page` em funções puras testáveis.
- [ ] Rotas no go_router para Detalhe, EditarPerfil e ConfiguracoesConta; trocar os 12 `Navigator.push`.
- [ ] Fila offline para denúncia com mídia (hoje o upload ao Cloudinary falha sem sinal).

## 🟢 Melhorias

- [ ] Atualizar `geolocator` (^9), `go_router` (^12) e `google_sign_in` (^6).
- [ ] Exportar dados também em JSON (portabilidade interoperável).
- [ ] Completar dark mode nas telas restantes.
- [ ] Revisão de UX/acessibilidade (Fase 5).
- [ ] Ampliar testes de regras de moderação e LGPD (06/10: +11 testes, ver bloco "brechas fechadas").
- [ ] Roteiro de demonstração para Unipê, MP e parceiros.
- [ ] Definir licença do repositório.

---

## ✅ Feito

- [x] Sprint 1 commitada em `Develop` (`52cf0da`, 01/10/2026).
- [x] Correções dos bugs dos testes manuais e sessão única commitadas em `Develop` (02/10/2026).
- [x] Implantação da Sprint 1: índices, `backfill:oculto` e regras (01–02/10/2026).
- [x] Reserva atômica de nome em `nomes_reservados`.
- [x] Novo ID `br.com.ecojp.app` e assinatura de release.
- [x] App Check ativado no app.
- [x] Suíte de carga k6 e CI na `Develop`.
- [x] ADR 0001: manter Firebase.
- [x] Consentimento com versão, exportar dados (PDF), excluir conta.
- [x] Papel de autoridade, ciclo oficial com auditoria, notificações de status.
- [x] Crashlytics e Analytics.
