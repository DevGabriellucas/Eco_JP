import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla o tema (claro / escuro / seguir o sistema) e persiste a escolha
/// do usuário localmente com `shared_preferences`.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _chave = 'theme_mode';

  @override
  ThemeMode build() {
    // Começa em "sistema" e carrega a preferência salva de forma assíncrona;
    // quando ela chega, o estado é atualizado e a UI reconstrói.
    _carregar();
    return ThemeMode.system;
  }

  Future<void> _carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modo = _fromString(prefs.getString(_chave));
      if (modo != state) state = modo;
    } catch (_) {
      // Sem persistência disponível: mantém o padrão (seguir o sistema).
    }
  }

  Future<void> definir(ThemeMode modo) async {
    state = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, modo.name);
    } catch (_) {
      // Ignora falha de escrita: a mudança já vale para a sessão atual.
    }
  }

  ThemeMode _fromString(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
