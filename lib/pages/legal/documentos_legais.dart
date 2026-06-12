import 'package:flutter/material.dart';

// ⚠️ Estes textos são um MODELO inicial em conformidade com a LGPD
// (Lei 13.709/2018). Antes de publicar de verdade, devem ser revisados
// por um profissional jurídico e ter o e-mail/contato do responsável preenchido.

const String kPoliticaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — EcoJP

O EcoJP valoriza a sua privacidade. Esta política explica quais dados coletamos, como os usamos e quais são os seus direitos, em conformidade com a Lei Geral de Proteção de Dados (LGPD — Lei nº 13.709/2018).

1. DADOS QUE COLETAMOS
• Dados de cadastro: nome e e-mail.
• Foto de perfil (opcional).
• Conteúdo das denúncias: fotos, descrição, categoria e localização (endereço e coordenadas geográficas).
• Interações: curtidas e comentários.

2. COMO USAMOS OS DADOS
• Para autenticar o seu acesso ao aplicativo.
• Para exibir as denúncias no feed, no mapa e nas estatísticas.
• Para identificar o autor de cada denúncia e comentário.
• Para melhorar a experiência no aplicativo.

3. COMPARTILHAMENTO
As denúncias registradas — incluindo foto, localização e nome do autor — ficam visíveis para os demais usuários autenticados do aplicativo, pois esse é o propósito colaborativo da plataforma. Não vendemos os seus dados a terceiros.

4. ARMAZENAMENTO
Os dados são armazenados em serviços de nuvem: as imagens no Cloudinary e os demais dados no Google Cloud Firestore (Firebase).

5. SEUS DIREITOS (LGPD)
A qualquer momento, você pode:
• Acessar e corrigir os dados do seu perfil.
• Excluir as suas denúncias.
• Solicitar a exclusão da sua conta e dos seus dados.

6. CONTATO
Para exercer seus direitos ou esclarecer dúvidas, entre em contato pelo e-mail de suporte do EcoJP.
''';

const String kTermosDeUso = '''
TERMOS DE USO — EcoJP

Ao criar uma conta e usar o EcoJP, você concorda com os termos abaixo.

1. OBJETIVO
O EcoJP é uma plataforma para registro e acompanhamento de ocorrências ambientais e urbanas na cidade de João Pessoa. As denúncias têm caráter informativo e colaborativo.

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(
          conteudo.trim(),
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
