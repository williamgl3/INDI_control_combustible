import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema (claro/oscuro/predeterminado del sistema),
/// persistida localmente — `shared_preferences` estaba en pubspec.yaml
/// desde el inicio del proyecto sin usarse hasta ahora.
///
/// Arranca en [ThemeMode.system] mientras se lee el valor guardado (la
/// lectura es casi instantánea, así que el destello es imperceptible en
/// la práctica) — no se bloquea el arranque de la app por esto, a
/// diferencia de `restaurarSesionProvider`, porque un tema equivocado por
/// un instante no manda al usuario a la pantalla equivocada.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'tema_preferido';

  @override
  ThemeMode build() {
    _cargar();
    return ThemeMode.system;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_key);
    if (guardado == null) return;
    state = ThemeMode.values.byName(guardado);
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, modo.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
