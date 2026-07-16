/// Reglas de validación centralizadas, como funciones puras reutilizables
/// por Login, Registro de chofer y EditarChoferDialog.
///
/// Cada función devuelve `null` si el valor es válido, o un mensaje de
/// error en español si no lo es (compatible con el `validator` de
/// [FormField]/[TextFormField]).
class Validators {
  const Validators._();

  static const int nombreMinLength = 2;
  static const int edadMin = 18;
  static const int edadMax = 75;
  static const int passwordMinLength = 8;

  static final RegExp _correoRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// TODO-SPEC: regex de usuario confirmada por el usuario en este chat.
  static final RegExp _usuarioRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  static String? nombre(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El nombre es obligatorio.';
    if (v.length < nombreMinLength) {
      return 'El nombre debe tener al menos $nombreMinLength caracteres.';
    }
    return null;
  }

  static String? edad(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'La edad es obligatoria.';
    final n = int.tryParse(v);
    if (n == null) return 'La edad debe ser un número.';
    if (n < edadMin || n > edadMax) {
      return 'La edad debe estar entre $edadMin y $edadMax años.';
    }
    return null;
  }

  static String? correo(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El correo es obligatorio.';
    if (!_correoRegex.hasMatch(v)) return 'Ingresa un correo válido.';
    return null;
  }

  static String? usuario(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El usuario es obligatorio.';
    if (!_usuarioRegex.hasMatch(v)) {
      return 'El usuario debe tener 3-30 caracteres: letras, números, "." o "_".';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria.';
    if (v.length < passwordMinLength) {
      return 'La contraseña debe tener al menos $passwordMinLength caracteres.';
    }
    return null;
  }

  static String? confirmarPassword(String? value, String original) {
    final v = value ?? '';
    if (v.isEmpty) return 'Confirma tu contraseña.';
    if (v != original) return 'Las contraseñas no coinciden.';
    return null;
  }

  static String? requerido(String? value, {String etiqueta = 'Este campo'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$etiqueta es obligatorio.';
    return null;
  }
}
