import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ⚠️ Estes textos são um MODELO inicial em conformidade com a LGPD
// (Lei 13.709/2018). Antes de publicar de verdade, devem ser revisados
// por um profissional jurídico e ter o e-mail/contato do responsável preenchido.

/// Versão dos documentos legais. Ao alterar o conteúdo da política ou dos
/// termos de forma relevante, incremente esta versão (formato data ISO) para
/// que o app peça um novo consentimento aos usuários já cadastrados.
const String kVersaoDocumentosLegais = '2026-06-17';

const String kPoliticaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — EcoJP
Versão 2026-06-17

O EcoJP valoriza a sua privacidade. Esta política explica quais dados coletamos, como os usamos e quais são os seus direitos, em conformidade com a Lei Geral de Proteção de Dados (LGPD — Lei nº 13.709/2018).

1. DADOS QUE COLETAMOS
• Dados de cadastro: nome e e-mail.
• Foto de perfil (opcional).
• Conteúdo das denúncias: fotos, vídeo (opcional), descrição, categoria e localização (endereço e coordenadas geográficas).
• Interações: curtidas e comentários.

2. COMO USAMOS OS DADOS
• Para autenticar o seu acesso ao aplicativo.
• Para exibir as denúncias no feed, no mapa e nas estatísticas.
• Para identificar o autor de cada denúncia e comentário, exceto quando a denúncia é feita de forma anônima.
• Para sugerir automaticamente a categoria da denúncia (ver item 4).
• Para melhorar a experiência no aplicativo.

3. DENÚNCIA ANÔNIMA
Ao registrar uma denúncia, você pode marcá-la como anônima. Nesse caso, o seu nome e a sua foto NÃO são gravados na denúncia e não aparecem para nenhum outro usuário, nem para os órgãos públicos. Mantemos internamente apenas o vínculo técnico necessário para que você possa gerenciar e excluir a sua própria denúncia.

4. INTELIGÊNCIA ARTIFICIAL
Para sugerir a categoria de uma denúncia, o título e a descrição (e, quando aplicável, a foto) podem ser enviados ao serviço de IA do Google (Gemini) por meio do Firebase AI Logic. A sugestão é apenas um auxílio — você sempre decide a categoria final antes de enviar.

5. COMPARTILHAMENTO
As denúncias registradas ficam visíveis para os demais usuários autenticados do aplicativo e para órgãos públicos cadastrados como autoridade, que realizam a triagem e o acompanhamento oficial (verificação, encaminhamento e resolução). Denúncias anônimas são compartilhadas sem o nome e a foto do autor. Não vendemos os seus dados a terceiros.

6. ARMAZENAMENTO E SEGURANÇA
As imagens e vídeos são armazenados no Cloudinary; os demais dados, no Google Cloud Firestore (Firebase). O acesso ao back-end é protegido pelo Firebase App Check, que impede o uso fora do aplicativo oficial.

7. RETENÇÃO
Mantemos os seus dados enquanto a sua conta existir. Ao excluir a sua conta, apagamos o seu perfil, as suas denúncias e as suas notificações. Comentários feitos em denúncias de outras pessoas podem permanecer sem vínculo visível com a sua conta.

8. SEUS DIREITOS (LGPD)
A qualquer momento, você pode:
• Acessar e corrigir os dados do seu perfil.
• Excluir as suas denúncias.
• Registrar denúncias de forma anônima.
• Solicitar a exclusão da sua conta e de todos os seus dados.

9. CONTATO
Para exercer seus direitos ou esclarecer dúvidas, entre em contato com o Encarregado de Proteção de Dados (DPO) pelo e-mail de suporte do EcoJP.
''';

const String kTermosDeUso = '''
TERMOS DE USO — EcoJP
Versão 2026-06-17

Ao criar uma conta e usar o EcoJP, você concorda com os termos abaixo.

1. OBJETIVO
O EcoJP é uma plataforma para registro e acompanhamento de ocorrências ambientais e urbanas na cidade de João Pessoa. As denúncias têm caráter informativo e colaborativo e podem ser triadas por órgãos públicos cadastrados (verificação, encaminhamento e resolução).

2. RESPONSABILIDADES DO USUÁRIO
• Fornecer informações verdadeiras.
• Não publicar conteúdo ofensivo, ilegal, falso ou que viole direitos de terceiros.
• Não utilizar o aplicativo para spam, assédio ou qualquer finalidade abusiva.
• Ser responsável pelo conteúdo (fotos e textos) que publicar.

3. CONTEÚDO
Você mantém a responsabilidade pelo conteúdo que publica. Conteúdo que viole estes termos poderá ser removido.

4. LIMITAÇÃO DE RESPONSABILIDADE
O EcoJP é uma ferramenta de registro e visualização colaborativa e não garante que as denúncias serão resolvidas por órgãos públicos.

5. CONTA
Você é responsável por manter a segurança da sua conta e da sua senha.

6. ALTERAÇÕES
Estes termos podem ser atualizados. O uso contínuo do aplicativo após mudanças implica concordância com a nova versão.
''';

/// Tela genérica que exibe um documento legal (Política de Privacidade / Termos).
class DocumentoLegalPage extends StatelessWidget {
  final String titulo;
  final String conteudo;

  const DocumentoLegalPage({
    super.key,
    required this.titulo,
    required this.conteudo,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.surface,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: pal.ink,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(
          conteudo.trim(),
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: pal.ink,
          ),
        ),
      ),
    );
  }
}
