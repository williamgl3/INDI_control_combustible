import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Datos que se lograron reconocer (best-effort) en la foto de un ticket
/// de gasolinera. Cualquier campo puede venir `null` si no se detectó con
/// suficiente confianza — esto es un APOYO visual para el admin, nunca un
/// bloqueo para que el chofer envíe su comprobación.
@immutable
class ResultadoOcrTicket {
  const ResultadoOcrTicket({this.litros, this.importe});

  final double? litros;
  final double? importe;

  bool get sinDatos => litros == null && importe == null;
}

abstract class TicketOcrService {
  Future<ResultadoOcrTicket> leerTicket(String rutaFoto);
}

/// Implementación real con Google ML Kit (reconocimiento de texto en el
/// propio dispositivo, sin conexión a internet).
///
/// Las expresiones regulares están ajustadas a tickets típicos de
/// gasolineras en México ("LITROS", "IMPORTE"/"TOTAL"). Ajustar si el
/// formato real de los proveedores de la obra difiere.
class MlKitTicketOcrService implements TicketOcrService {
  const MlKitTicketOcrService();

  static final _litrosRegex = RegExp(
    r'LITROS?[:\s]*\$?\s*(\d+[.,]\d+)',
    caseSensitive: false,
  );
  static final _importeRegex = RegExp(
    r'(?:IMPORTE|TOTAL)[:\s]*\$?\s*(\d+[.,]\d+)',
    caseSensitive: false,
  );

  @override
  Future<ResultadoOcrTicket> leerTicket(String rutaFoto) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final imagen = InputImage.fromFilePath(rutaFoto);
      final reconocido = await recognizer.processImage(imagen);
      return _extraer(reconocido.text);
    } finally {
      await recognizer.close();
    }
  }

  ResultadoOcrTicket _extraer(String texto) {
    double? parsear(RegExpMatch? match) {
      if (match == null) return null;
      return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    }

    return ResultadoOcrTicket(
      litros: parsear(_litrosRegex.firstMatch(texto)),
      importe: parsear(_importeRegex.firstMatch(texto)),
    );
  }
}
