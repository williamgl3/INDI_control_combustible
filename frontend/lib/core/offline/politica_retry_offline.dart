import 'dart:math';

import '../../data/api_client.dart';
import 'metadata_operacion_offline.dart';

class PoliticaBackoffOffline {
  PoliticaBackoffOffline({Random? random, DateTime Function()? reloj})
    : _random = random ?? Random(),
      _reloj = reloj ?? DateTime.now;

  final Random _random;
  final DateTime Function() _reloj;
  static const maximo = Duration(minutes: 15);
  static const maxIntentosAutomaticos = 10;

  DateTime? proximoIntento({required int intentos, Duration? retryAfter}) {
    if (intentos >= maxIntentosAutomaticos) return null;
    final exponente = intentos.clamp(0, 9);
    final techoSegundos = min(maximo.inSeconds, 2 * (1 << exponente));
    final jitter = Duration(seconds: _random.nextInt(techoSegundos + 1));
    final espera = retryAfter != null && retryAfter > jitter
        ? retryAfter
        : jitter;
    return _reloj().add(espera);
  }
}

class ClasificacionErrorOffline {
  const ClasificacionErrorOffline(this.estado, {this.requiereLogin = false});

  final EstadoOperacionOffline estado;
  final bool requiereLogin;
}

class ClasificadorHttpOffline {
  const ClasificadorHttpOffline();

  ClasificacionErrorOffline clasificar(ApiException error) {
    final status = error.status;
    if (status == null ||
        error.categoriaTransporte != CategoriaTransporte.ninguna) {
      return const ClasificacionErrorOffline(
        EstadoOperacionOffline.errorTransitorio,
      );
    }
    if (status == 401) {
      return const ClasificacionErrorOffline(
        EstadoOperacionOffline.errorTransitorio,
        requiereLogin: true,
      );
    }
    if (status == 408 || status == 429 || status >= 500) {
      return const ClasificacionErrorOffline(
        EstadoOperacionOffline.errorTransitorio,
      );
    }
    if (status == 409) {
      return const ClasificacionErrorOffline(EstadoOperacionOffline.conflicto);
    }
    if (status == 403 || status == 400 || status == 422) {
      return const ClasificacionErrorOffline(
        EstadoOperacionOffline.errorPermanente,
      );
    }
    if (status == 404) {
      return const ClasificacionErrorOffline(
        EstadoOperacionOffline.requiereRevision,
      );
    }
    return const ClasificacionErrorOffline(
      EstadoOperacionOffline.errorPermanente,
    );
  }
}

MetadataOperacionOffline metadataTrasErrorOffline(
  MetadataOperacionOffline actual,
  ApiException error, {
  ClasificadorHttpOffline clasificador = const ClasificadorHttpOffline(),
  PoliticaBackoffOffline? backoff,
  DateTime Function()? reloj,
}) {
  final ahora = (reloj ?? DateTime.now)();
  final clasificacion = clasificador.clasificar(error);
  final intentos = actual.intentos + 1;
  final politica = backoff ?? PoliticaBackoffOffline(reloj: () => ahora);
  return actual.copiar(
    estado: clasificacion.estado,
    intentos: intentos,
    ultimoIntento: ahora,
    proximoIntento:
        clasificacion.estado == EstadoOperacionOffline.errorTransitorio
        ? politica.proximoIntento(
            intentos: intentos,
            retryAfter: error.retryAfter,
          )
        : null,
    limpiarProximoIntento:
        clasificacion.estado != EstadoOperacionOffline.errorTransitorio,
    ultimoError: error.mensaje,
    ultimoStatus: error.status,
    limpiarUltimoStatus: error.status == null,
    ultimoCodigo: error.codigo,
    limpiarUltimoCodigo: error.codigo == null,
    requiereLogin: clasificacion.requiereLogin,
  );
}
