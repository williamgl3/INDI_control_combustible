/// Reglas de validación centralizadas, como funciones puras reutilizables
/// por Login, Registro de chofer y EditarChoferDialog.
///
/// Cada función devuelve `null` si el valor es válido, o un mensaje de
/// error en español si no lo es (compatible con el `validator` de
/// [FormField]/[TextFormField]).
class Validators {
  const Validators._();

  static const int nombreMinLength = 2;
  static const int passwordMinLength = 8;

  static final RegExp _correoRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Regex de usuario: 3-30 caracteres alfanuméricos, puntos o guiones bajos.
  /// Confirmada en SPEC.md.
  static final RegExp _usuarioRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  /// Letras (con acentos/ñ) y espacios — sin dígitos ni símbolos. Mismo
  /// patrón que `apellidoRegex` en el backend (`auth.routes.ts`,
  /// `usuarios.routes.ts`) — no reinventar el límite.
  static final RegExp _soloLetrasRegex = RegExp(r'^[a-zA-ZÀ-ÿñÑ\s]+$');

  /// Placa mexicana: 2-3 letras, guion, 3-5 dígitos, guion, 1 letra
  /// (ej. "AA-1234-A", "AAA-123-A"). El rango de dígitos es más amplio
  /// que el formato típico de 3-4 porque el catálogo real de GAMI trae
  /// al menos una placa con 5 ("PH-24896-C") — de haber excluido ese
  /// caso, el formulario habría rechazado una unidad que ya circula.
  static final RegExp _placaRegex = RegExp(r'^[A-Z]{2,3}-\d{3,5}-[A-Z]$');

  /// Solo valida el formato cuando el campo aplica (Vehículo/Marimba) —
  /// el llamador decide eso; aquí solo se exige que, si hay un valor,
  /// tenga forma de placa.
  static String? placa(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'Las placas son obligatorias.';
    if (!_placaRegex.hasMatch(v)) {
      return 'Formato de placa no reconocido (ej. AA-1234-A).';
    }
    return null;
  }

  static String? nombre(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El nombre es obligatorio.';
    if (v.length < nombreMinLength) {
      return 'El nombre debe tener al menos $nombreMinLength caracteres.';
    }
    return null;
  }

  /// Apellido paterno/materno: obligatorio, sin números. `etiqueta`
  /// personaliza el mensaje ("El apellido paterno..."/"El apellido
  /// materno...").
  static String? apellido(String? value, {String etiqueta = 'El apellido'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$etiqueta es obligatorio.';
    if (v.length < nombreMinLength) {
      return '$etiqueta debe tener al menos $nombreMinLength caracteres.';
    }
    if (!_soloLetrasRegex.hasMatch(v)) {
      return '$etiqueta no debe contener números.';
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

  /// Numérico genérico, obligatorio y mayor a cero — para montos/valores
  /// que no tienen una regla de negocio propia (a diferencia de
  /// [kilometraje], que sí valida contra el último km registrado).
  static String? numeroPositivo(String? value, {String etiqueta = 'El valor'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$etiqueta es obligatorio.';
    final n = double.tryParse(v);
    if (n == null) return 'Ingresa un número válido.';
    if (n <= 0) return '$etiqueta debe ser mayor a cero.';
    return null;
  }

  /// Kilometraje del tablero: numérico, positivo y, si se conoce el
  /// último km registrado del vehículo (`ultimoKm`), mayor a ese valor
  /// (el odómetro no puede retroceder).
  static String? kilometraje(String? value, {double? ultimoKm}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El kilometraje es obligatorio.';
    final km = double.tryParse(v);
    if (km == null) return 'Ingresa un número válido.';
    if (km <= 0) return 'El kilometraje debe ser mayor a cero.';
    if (ultimoKm != null && km <= ultimoKm) {
      return 'Debe ser mayor al último km registrado (${ultimoKm.toStringAsFixed(0)}).';
    }
    return null;
  }
}
