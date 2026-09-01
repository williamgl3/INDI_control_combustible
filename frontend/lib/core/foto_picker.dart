import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Abstrae la captura de fotos con la cámara para que las pantallas no
/// dependan directamente de `image_picker` (facilita probarlas con un
/// fake en widget tests, donde no hay cámara real disponible).
abstract class FotoPicker {
  /// Devuelve la ruta local de la foto tomada, o `null` si el usuario
  /// canceló la captura.
  Future<String?> tomarFoto();

  /// Lee los bytes del XFile capturado. También funciona con la referencia
  /// temporal que image_picker entrega en Web.
  Future<Uint8List> leerBytes(String ruta);
}

class ImagePickerFotoPicker implements FotoPicker {
  const ImagePickerFotoPicker();

  @override
  Future<String?> tomarFoto() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    return archivo?.path;
  }

  @override
  Future<Uint8List> leerBytes(String ruta) {
    return XFile(ruta).readAsBytes();
  }
}

/// Resultado de capturar foto + importar a almacenamiento durable.
class FotoCapturada {
  const FotoCapturada({required this.bytes, required this.rutaTemporal});

  final Uint8List bytes;
  final String rutaTemporal;
}
