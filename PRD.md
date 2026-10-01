# PRD — EcoJP

> Documento de requisitos do produto. Descreve **o quê** e **por quê**.
> O **como** está em [ARCHITECTURE.md](ARCHITECTURE.md); o visual, em [DESIGN.md](DESIGN.md).

**Versão:** 1.0 · **Atualizado em:** 01/10/2026 · **Responsável:** Gabriel Lucas

---

## 1. Problema

Em João Pessoa, descarte irregular de lixo, queimadas, esgoto a céu aberto, buracos e
alagamentos são vistos todos os dias, mas o cidadão não tem um canal simples, seguro e
rastreável para denunciar. Os canais existentes (telefone, ouvidoria, redes sociais)
não dão retorno, não mostram o andamento e expõem quem denuncia.

## 2. Visão

Um aplicativo móvel em que o cidadão registra o problema em menos de um minuto, com foto
e localização, acompanha o andamento oficial e, se quiser, permanece anônimo perante a
comunidade. Do outro lado, a autoridade recebe uma fila organizada, verifica, encaminha e
resolve, e cada passo fica auditado.

## 3. Contexto institucional

O projeto nasceu como trabalho de disciplina no Unipê e virou candidatura institucional:
edital de inovação (Prêmio de Inovação CSED 2026), apresentação ao **Ministério Público**
e à **reitoria do Unipê**, e piloto com parceiro externo.

Isso define o que é prioridade:

1. **Conformidade LGPD auditável.** O MP fiscaliza a LGPD; uma promessa da política de
   privacidade que o código não cumpre pesa mais que qualquer dívida técnica.
2. **Demo que não falha ao vivo.**
3. **Maturidade técnica documentada** (ADRs, testes, CI).
4. Escala bruta vem depois. O risco real de escala é custo por padrão de leitura e mídia,
   não número de usuários simultâneos.

## 4. Público-alvo

| Persona | Quem é | O que precisa |
|---|---|---|
| **Cidadão** | Morador de João Pessoa com smartphone | Denunciar rápido, acompanhar, não sofrer retaliação |
| **Autoridade** | Servidor de órgão público ou parceiro | Fila de triagem, mudar status oficial, moderar abuso, relatórios |
| **Comunidade** | Outros cidadãos | Ver o que acontece no bairro, apoiar (curtir/comentar) |

## 5. Escopo

### 5.1 No escopo (MVP / piloto)

**Denúncia**
- Categorias: lixo, queimada, buraco, árvore caída, enchente, esgoto, iluminação, outros.
- Até 3 fotos ou 1 vídeo, com EXIF/GPS removido antes do upload.
- Localização por GPS ou mapa, restrita ao município de João Pessoa (geofence).
- Denúncia anônima: nome e foto nunca são gravados no documento público e as coordenadas
  são arredondadas (~100 m). O anonimato vale perante a comunidade, não perante o órgão.

**Acompanhamento**
- Ciclo oficial: pendente → em análise → confirmada → encaminhada → resolvida
  (ou não confirmada), com carimbo de tempo e evento de auditoria em cada passo.
- Notificação ao cidadão a cada avanço do status.

**Comunidade**
- Feed paginado, mapa com marcadores e zonas mais afetadas, curtidas e comentários.
- Perfil público, seguir usuários, conquistas.
- Guia de coleta de lixo por bairro.

**Autoridade**
- Papel concedido pela coleção `roles` (sem custom claims).
- Fila de verificação (por antiguidade) e fila de moderação de conteúdo denunciado.
- Ocultar conteúdo abusivo; reverter status como ação própria.
- Painel de estatísticas (funil, tempos médios, ranking de bairros) e relatório em PDF.

**Conta e LGPD**
- Login por e-mail/senha (verificação obrigatória para postar) e Google.
- Nome público único (reserva atômica em `nomes_reservados`).
- Consentimento registrado com versão e data; re-consentimento quando a política muda.
- Exportar meus dados (PDF, incluindo denúncias anônimas).
- Excluir conta e dados.

### 5.2 Fora do escopo (por enquanto)

- Integração direta com sistemas da prefeitura.
- Sugestão de categoria por IA.
- Chat entre cidadão e autoridade.
- Versão web pública (existe build web apenas para desenvolvimento).
- Outros municípios além de João Pessoa.

## 6. Requisitos não funcionais

| Área | Requisito |
|---|---|
| Segurança | Nada confia no cliente; toda escrita validada pelas Firestore Rules; negação por padrão; App Check |
| Privacidade | Sem metadados em mídia; anônima não grava UID no doc público; exclusão de conta efetiva |
| Offline | Denunciar na rua, às vezes sem sinal: o Firestore enfileira escritas e mantém cache |
| Custo | Piloto dentro da cota gratuita do Firebase e do Cloudinary; mídia comprimida no upload |
| Qualidade | `flutter analyze` limpo, testes Dart e de regras verdes no CI antes de merge |
| Plataformas | Android 8.0+ (minSdk 26) e iOS 15.0+ |
| Idioma | Todo texto de interface em português do Brasil |

## 7. Métricas de sucesso do piloto

- Tempo médio para registrar uma denúncia < 60 s.
- % de denúncias que recebem primeiro status oficial em até 72 h.
- % de denúncias resolvidas no período do piloto.
- Zero incidente de exposição de dado pessoal.
- Custo mensal de infraestrutura dentro da cota gratuita.

## 8. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Política de privacidade sem revisão jurídica | Alto (MP) | Revisão jurídica + DPO antes de publicar |
| Exclusão de conta não apaga mídia do Cloudinary | Alto (LGPD) | Cloud Function com upload assinado |
| Uma denúncia viraliza e satura o documento | Médio | Mover reações para subcoleção/contador distribuído |
| App Check não imposto | Médio | Registrar `br.com.ecojp.app` e ligar a imposição |
| Demo falha por config (chave do Maps, ID do app) | Alto | Checklist de config antes de cada apresentação |

## 9. Referências

- [ROADMAP.md](ROADMAP.md) — plano de evolução por fases
- [docs/adr/0001-backend-firebase-vs-supabase.md](docs/adr/0001-backend-firebase-vs-supabase.md)
- [docs/Code-review.md](docs/Code-review.md) — revisão que originou a Sprint 1
- [docs/Sprint1-resumo.md](docs/Sprint1-resumo.md)
