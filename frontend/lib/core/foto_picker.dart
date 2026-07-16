import 'package:image_picker/image_picker.dart';

/// Abstrae la captura de fotos con la cámara para que las pantallas no
/// dependan directamente de `image_picker` (facilita probarlas con un
/// fake en widget tests, donde no hay cámara real disponible).
abstract class FotoPicker {
  /// Devuelve la ruta local de la foto tomada, o `null` si el usuario
  /// canceló la captura.
  Future<String?> tomarFoto();
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
}
