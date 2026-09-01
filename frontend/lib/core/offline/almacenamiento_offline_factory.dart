import 'almacenamiento_offline.dart';
import 'almacenamiento_offline_factory_stub.dart'
    if (dart.library.io) 'almacenamiento_offline_factory_io.dart'
    if (dart.library.js_interop) 'almacenamiento_offline_factory_web.dart';

AlmacenamientoOffline crearAlmacenamientoOffline() => crearImplementacion();
