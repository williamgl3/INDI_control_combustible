import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` si el dispositivo reporta alguna conexión de red disponible
/// (wifi o datos móviles) — no garantiza que el backend responda (para
/// eso están los `ApiException` de `ApiClient`), pero permite avisar de
/// inmediato "estás sin conexión" sin esperar a que una petición falle.
///
/// `connectivity_plus` estaba en pubspec.yaml desde el inicio del
/// proyecto pero nunca se usó — la app no tenía ningún indicio de
/// "sin internet" pese a ser el caso de uso central (choferes en obra
/// con señal irregular).
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hayConexion(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hayConexion);
});

bool _hayConexion(List<ConnectivityResult> resultados) {
  return resultados.any((r) => r != ConnectivityResult.none);
}
