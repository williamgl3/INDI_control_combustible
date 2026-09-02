import 'almacenamiento_offline.dart';
import 'almacenamiento_offline_filesystem.dart';

AlmacenamientoOffline crearImplementacion() =>
    AlmacenamientoOfflineFilesystem();
