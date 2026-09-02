import 'package:flutter/material.dart';

/// `ElevatedButton` primario con estado de carga incorporado — antes cada
/// pantalla repetía a mano el mismo `onPressed: cargando ? null : accion` +
/// `child: cargando ? SizedBox(spinner) : Text(...)` (login, registro,
/// solicitar/comprobar carga, cerrar día, cambiar contraseña, reportar
/// incidencia). Aquí el llamador solo pasa [onPressed] (sin el null-guard) y
/// [cargando]; el botón se deshabilita y muestra el spinner por su cuenta.
class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({
    super.key,
    required this.onPressed,
    required this.cargando,
    required this.child,
    this.backgroundColor,
  });

  final VoidCallback onPressed;
  final bool cargando;
  final Widget child;

  /// `null` (default) deja el color que ya trae el tema
  /// (`colors.primary`, ver `ElevatedButtonThemeData` en `app_theme.dart`)
  /// — pásalo explícito solo cuando UNA pantalla puntual necesite otro
  /// tono (ej. el "Ingresar" del login, para igualar el azul del
  /// degradado del header en vez del azul de marca general).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Altura mínima más grande que el default del tema: este botón es el
      // CTA principal de los flujos de chofer (solicitar/comprobar carga,
      // cerrar día, login, registro) — pensado para tocarse con una mano,
      // a veces con guante, en obra. El resto del estilo (color, radio,
      // tipografía) sigue viniendo del tema — solo se agranda el alto.
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.center,
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      onPressed: cargando ? null : onPressed,
      child: cargando
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : child,
    );
  }
}
