import 'package:intl/intl.dart';

/// Formateo de dinero/cantidades con separador de miles — antes cada
/// pantalla armaba el texto a mano (`'\$${valor.toStringAsFixed(0)}'`), así
/// que un presupuesto de 50000 pesos se leía "$50000" en vez de "$50,000"
/// en Finanzas, Dashboard, Concentrado y los CSV exportados.
final _formatoMoneda = NumberFormat.currency(
  locale: 'es_MX',
  symbol: '\$',
  decimalDigits: 0,
);

final _formatoMonedaDecimal = NumberFormat.currency(
  locale: 'es_MX',
  symbol: '\$',
  decimalDigits: 2,
);

final _formatoNumero = NumberFormat.decimalPattern('es_MX');

/// Ej. "$50,000" — sin decimales, para montos grandes (presupuesto,
/// totales).
String formatearMoneda(num valor) => _formatoMoneda.format(valor);

/// Ej. "$24.50" — con 2 decimales, para precios por unidad.
String formatearMonedaDecimal(num valor) => _formatoMonedaDecimal.format(valor);

/// Ej. "1,234" — separador de miles sin símbolo de moneda, para litros/km
/// grandes.
String formatearNumero(num valor) => _formatoNumero.format(valor);

/// Como [formatearNumero] pero con una cantidad fija de decimales — usado
/// por `CeldaEditable` para mostrar el valor ya guardado (el modo edición
/// sigue mostrando el número "crudo", sin separadores, para que sea fácil
/// de parsear de vuelta al confirmar).
String formatearNumeroConDecimales(num valor, int decimales) {
  return NumberFormat(
    '#,##0${decimales > 0 ? '.${'0' * decimales}' : ''}',
    'es_MX',
  ).format(valor);
}
