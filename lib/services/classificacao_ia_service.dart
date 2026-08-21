import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

/// Sugestão de categoria por IA (Gemini via Google Generative AI).
///
/// Usa a API do Google Generative AI com um modelo Gemini.
/// É só uma sugestão: o usuário sempre pode escolher outra categoria antes
/// de enviar a denúncia (humano decide por último).
class ClassificacaoIaService {
  static final ClassificacaoIaService instance = ClassificacaoIaService();

  static const categorias = [
    'Lixo',
    'Queimada',
    'Buraco',
    'Árvores caídas',
    'Enchentes',
    'Esgoto',
    'Falta iluminação',
    'Outros',
  ];

  GenerativeModel get _modelo {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: '', // TODO: Adicionar chave de API
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Retorna uma categoria sugerida (uma das [categorias]) a partir do
  /// título e descrição, ou null se a IA não respondeu algo utilizável.
  Future<String?> sugerirCategoria({
    required String titulo,
    required String descricao,
  }) async {
    if (titulo.trim().isEmpty && descricao.trim().isEmpty) return null;

    final prompt =
        'Classifique a denúncia urbana/ambiental abaixo em exatamente uma '
        'destas categorias: ${categorias.join(', ')}.\n\n'
        'Título: ${titulo.trim()}\n'
        'Descrição: ${descricao.trim()}\n\n'
        'Responda só com JSON no formato {"categoria": "<categoria exata>"}.';

    try {
      final resposta = await _modelo
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      final texto = resposta.text;
      if (texto == null || texto.trim().isEmpty) return null;

      final dados = jsonDecode(texto) as Map<String, dynamic>;
      final categoria = dados['categoria'] as String?;
      return categorias.contains(categoria) ? categoria : null;
    } catch (e) {
      debugPrint('Erro ao sugerir categoria por IA: $e');
      return null;
    }
  }
}
