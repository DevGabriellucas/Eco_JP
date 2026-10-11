import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ⚠️ Estes textos são um MODELO inicial em conformidade com a LGPD
// (Lei 13.709/2018). Antes de publicar de verdade, devem ser revisados
// por um profissional jurídico e ter o e-mail/contato do responsável preenchido.

/// Versão dos documentos legais. Ao alterar o conteúdo da política ou dos
/// termos de forma relevante, incremente esta versão (formato data ISO) para
/// que o app peça um novo consentimento aos usuários já cadastrados.
const String kVersaoDocumentosLegais = '2026-10-01';

const String kPoliticaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — EcoJP
Versão 2026-10-01

O EcoJP valoriza a sua privacidade. Esta política explica quais dados coletamos, como os usamos e quais são os seus direitos, em conformidade com a Lei Geral de Proteção de Dados (LGPD — Lei nº 13.709/2018).

1. DADOS QUE COLETAMOS
• Dados de cadastro: nome e e-mail. Se você entrar com a conta Google, recebemos também o nome e a foto dessa conta.
• Foto de perfil (opcional).
• Conteúdo das denúncias: fotos, vídeo (opcional), descrição, categoria e localização (endereço, bairro e coordenadas geográficas).
• Interações: curtidas, comentários e compartilhamentos (registramos que você compartilhou, não para quem).
• Dados técnicos: identificador da conta e eventos de uso (ex.: denúncia criada, com a categoria e se foi anônima), e relatórios de falhas do aplicativo.

Antes do envio, o aplicativo remove das fotos e vídeos os metadados gravados pela câmera, inclusive a localização GPS e o modelo do aparelho.

2. COMO USAMOS OS DADOS
• Para autenticar o seu acesso ao aplicativo.
• Para exibir as denúncias no feed, no mapa e nas estatísticas.
• Para identificar o autor de cada denúncia e comentário, exceto quando a denúncia é feita de forma anônima (ver item 3).
• Para melhorar a experiência no aplicativo.

3. DENÚNCIA ANÔNIMA — LEIA COM ATENÇÃO
Ao registrar uma denúncia, você pode marcá-la como anônima. É importante que você entenda exatamente o que isso significa:

• Perante os demais usuários do aplicativo: o seu nome e a sua foto NÃO são gravados no registro público da denúncia e não aparecem para nenhum outro usuário. A localização da denúncia anônima é publicada de forma aproximada (cerca de 100 metros), para não revelar o ponto exato de onde você a enviou.

• Atenção: se você comentar na sua própria denúncia anônima, o comentário mostra o seu nome e a sua foto, como qualquer outro comentário.

• Perante o órgão público responsável: o vínculo entre você e a denúncia é mantido em uma área de acesso restrito, separada do registro público. Esse vínculo permite que VOCÊ gerencie e exclua a sua própria denúncia e permite que o órgão público cadastrado como autoridade identifique o autor quando isso for necessário ao andamento oficial do caso — por exemplo, para solicitar informações complementares ou dar seguimento legal à denúncia.

• Em resumo: a denúncia anônima protege a sua identidade diante da comunidade de usuários, mas NÃO diante do órgão público que recebe e apura a denúncia. Se você não deseja que o órgão público possa identificá-lo em nenhuma circunstância, não registre a denúncia por este aplicativo.

4. COMPARTILHAMENTO
As denúncias registradas ficam visíveis para os demais usuários autenticados do aplicativo e para órgãos públicos cadastrados como autoridade, que realizam a triagem e o acompanhamento oficial (verificação, encaminhamento e resolução). Denúncias anônimas são exibidas sem o nome e a foto do autor, observado o item 3 acima. Não vendemos os seus dados a terceiros.

5. ARMAZENAMENTO, SEGURANÇA E OPERADORES
Para funcionar, o EcoJP usa os seguintes serviços (operadores de dados), que tratam dados apenas para prestar o serviço ao aplicativo:
• Google Firebase: autenticação (inclusive "Entrar com Google"), banco de dados (Cloud Firestore), Firebase App Check, Firebase Analytics (estatísticas de uso vinculadas a um identificador da conta) e Firebase Crashlytics (relatórios de falhas).
• Cloudinary: armazenamento e entrega das fotos e vídeos das denúncias e das fotos de perfil.
• Busca de endereços: OpenStreetMap (Nominatim) e Photon (komoot), ViaCEP e, quando configurado, Google Maps/Places. O texto digitado no campo de endereço e as coordenadas usadas em "usar localização atual" são enviados a esses serviços para encontrar o endereço.
• Google Maps: exibição do mapa.

O acesso ao back-end é restringido pelo Firebase App Check, que limita o uso das nossas APIs a instâncias legítimas do aplicativo oficial, e por regras de segurança que validam cada leitura e escrita no servidor. Conteúdo ocultado pela moderação fica visível apenas para o autor e para a autoridade.

6. RETENÇÃO
Mantemos os seus dados enquanto a sua conta existir. Ao excluir a sua conta, apagamos do banco de dados o seu perfil, o seu registro de consentimento, as suas denúncias (inclusive as anônimas), as suas notificações, os seus registros de compartilhamento e os seus vínculos de seguir/ser seguido. Comentários feitos por você em denúncias de outras pessoas são mantidos, sem vínculo visível com a sua conta, para preservar o contexto das discussões — conforme o art. 18, IV, da LGPD, que admite a anonimização como alternativa à eliminação.

Arquivos de mídia: os arquivos de fotos e vídeos ficam no Cloudinary e, nesta versão do aplicativo, não são apagados automaticamente junto com a conta — deixam de aparecer no aplicativo, mas o endereço do arquivo pode continuar acessível a quem já o tinha. Para solicitar a remoção definitiva desses arquivos, use o contato do item 8.

O vínculo do autor com a denúncia anônima (item 3) é acessível apenas ao próprio autor e às contas de autoridade.

7. SEUS DIREITOS (LGPD)
A qualquer momento, você pode:
• Acessar e corrigir os dados do seu perfil.
• Exportar os seus dados, inclusive as denúncias anônimas (Conta e privacidade → Exportar meus dados).
• Excluir as suas denúncias.
• Registrar denúncias de forma anônima.
• Solicitar a exclusão da sua conta e de todos os seus dados.

8. CONTATO
Para exercer seus direitos ou esclarecer dúvidas, entre em contato com o Encarregado de Proteção de Dados (DPO) pelo e-mail de suporte do EcoJP.
''';

const String kTermosDeUso = '''
TERMOS DE USO — EcoJP
Versão 2026-10-01

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
