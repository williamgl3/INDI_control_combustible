import '../cola_solicitudes_offline.dart';
import '../offline/metadata_operacion_offline.dart';
import 'operacion_sincronizacion_view.dart';

/// Resultado del agregador: operaciones convertidas a la vista unificada
/// y resumen de conteos por estado visual.
class CentroSincronizacionData {
  const CentroSincronizacionData({
    required this.operaciones,
    required this.conteoPorEstado,
    this.total = 0,
    this.requiereAtencion = 0,
    this.reintentables = 0,
  });

  final List<OperacionSincronizacionView> operaciones;
  final Map<EstadoVisualSincronizacion, int> conteoPorEstado;
  final int total;
  final int requiereAtencion;
  final int reintentables;
}

/// Lee las 8 colas offline y las convierte en una lista unificada de
/// [OperacionSincronizacionView] filtrada por el usuario actual.
///
/// Esta clase es puramente funcional — no mantiene estado ni se suscribe
/// a providers. La invocación se hace desde el provider que observa las
/// colas y el tick de operaciones.
class AgregadorSincronizacion {
  /// Convierte una cola de solicitudes en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasSolicitudes(
    List<SolicitudPendienteOffline> items,
  ) {
    return items.map((s) {
      final puedeReintentar =
          s.metadata.estado != EstadoOperacionOffline.sincronizando &&
          s.metadata.estado != EstadoOperacionOffline.sincronizada &&
          s.metadata.estado != EstadoOperacionOffline.requiereRevision;
      final requiereAtencion =
          s.metadata.requiereLogin ||
          s.metadata.estado == EstadoOperacionOffline.errorPermanente ||
          s.metadata.estado == EstadoOperacionOffline.requiereRevision;

      // Mapear EstadoSolicitudOffline → EstadoOperacionOffline para el modelo
      final estadoOperacion = _mapearEstadoSolicitud(s.estado);

      return OperacionSincronizacionView(
        idLocal: s.idLocal,
        idServer: s.idRemoto,
        tipo: TipoOperacionOffline.solicitud,
        titulo: 'Solicitud de carga',
        descripcion: _descripcionSolicitud(s),
        estado: estadoOperacion,
        estadoVisual: _visualDeMetadata(s.metadata),
        usuarioId: s.usuarioId,
        intentos: s.metadata.intentos,
        creadaEn: s.creadaEn,
        proximoIntento: s.metadata.proximoIntento,
        ultimoError: s.metadata.ultimoError,
        codigoError: s.metadata.ultimoCodigo,
        ultimoStatus: s.metadata.ultimoStatus,
        requiereLogin: s.metadata.requiereLogin,
        idempotencyKey: s.metadata.idempotencyKey,
        archivos: _archivosDeSolicitud(s),
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: s.vehiculoId,
            tipo: TipoOperacionOffline.solicitud,
            descripcion: 'Vehículo ${s.vehiculoId}',
          ),
        ],
        puedeReintentar: puedeReintentar,
        requiereAtencion: requiereAtencion,
      );
    }).toList();
  }

  /// Convierte una cola de comprobar carga en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasComprobarCarga(
    List<ComprobarCargaPendienteOffline> items,
  ) {
    return items.map((c) {
      return OperacionSincronizacionView(
        idLocal: c.idLocal,
        tipo: TipoOperacionOffline.comprobarCarga,
        titulo: 'Comprobar carga',
        descripcion: _descripcionComprobarCarga(c),
        estado: c.metadata.estado,
        estadoVisual: _visualDeMetadata(c.metadata),
        usuarioId: c.choferId,
        intentos: c.metadata.intentos,
        creadaEn: c.creadaEn,
        proximoIntento: c.metadata.proximoIntento,
        ultimoError: c.metadata.ultimoError,
        codigoError: c.metadata.ultimoCodigo,
        ultimoStatus: c.metadata.ultimoStatus,
        requiereLogin: c.metadata.requiereLogin,
        idempotencyKey: c.metadata.idempotencyKey,
        archivos: _archivosComunes(c.fotoTicketPath, c.fotoTableroPath),
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: c.vehiculoId,
            tipo: TipoOperacionOffline.comprobarCarga,
            descripcion: 'Vehículo ${c.vehiculoId}',
          ),
        ],
        puedeReintentar: _puedeReintentar(c.metadata),
        requiereAtencion: _requiereAtencion(c.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de cerrar día en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasCerrarDia(
    List<CerrarDiaPendienteOffline> items,
  ) {
    return items.map((c) {
      return OperacionSincronizacionView(
        idLocal: c.idLocal,
        tipo: TipoOperacionOffline.cerrarDia,
        titulo: 'Cerrar día',
        descripcion: _descripcionCerrarDia(c),
        estado: c.metadata.estado,
        estadoVisual: _visualDeMetadata(c.metadata),
        usuarioId: c.choferId,
        intentos: c.metadata.intentos,
        creadaEn: c.creadaEn,
        proximoIntento: c.metadata.proximoIntento,
        ultimoError: c.metadata.ultimoError,
        codigoError: c.metadata.ultimoCodigo,
        ultimoStatus: c.metadata.ultimoStatus,
        requiereLogin: c.metadata.requiereLogin,
        idempotencyKey: c.metadata.idempotencyKey,
        archivos: [if (c.fotoTableroPath.isNotEmpty) ...[
          ArchivoSincronizacionView(
            ruta: c.fotoTableroPath,
            verificado: true,
          ),
        ]],
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: c.cargaId,
            tipo: TipoOperacionOffline.cerrarDia,
            descripcion: 'Carga ${c.cargaId}',
          ),
        ],
        puedeReintentar: _puedeReintentar(c.metadata),
        requiereAtencion: _requiereAtencion(c.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de incidencias en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasIncidencias(
    List<IncidenciaPendienteOffline> items,
  ) {
    return items.map((i) {
      return OperacionSincronizacionView(
        idLocal: i.idLocal,
        tipo: TipoOperacionOffline.incidencia,
        titulo: 'Incidencia',
        descripcion: i.descripcion.isNotEmpty ? i.descripcion : 'Sin descripción',
        estado: i.metadata.estado,
        estadoVisual: _visualDeMetadata(i.metadata),
        usuarioId: i.usuarioId,
        intentos: i.metadata.intentos,
        creadaEn: i.creadaEn,
        proximoIntento: i.metadata.proximoIntento,
        ultimoError: i.metadata.ultimoError,
        codigoError: i.metadata.ultimoCodigo,
        ultimoStatus: i.metadata.ultimoStatus,
        requiereLogin: i.metadata.requiereLogin,
        idempotencyKey: i.metadata.idempotencyKey,
        archivos: [
          if (i.fotoPath != null && i.fotoPath!.isNotEmpty)
            ArchivoSincronizacionView(
              ruta: i.fotoPath!,
              verificado: true,
            ),
        ],
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: i.vehiculoId,
            tipo: TipoOperacionOffline.incidencia,
            descripcion: 'Vehículo ${i.vehiculoId}',
          ),
        ],
        puedeReintentar: _puedeReintentar(i.metadata),
        requiereAtencion: _requiereAtencion(i.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de evidencias en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasEvidencias(
    List<EvidenciaPendienteOffline> items,
  ) {
    return items.map((e) {
      return OperacionSincronizacionView(
        idLocal: e.idLocal,
        tipo: TipoOperacionOffline.evidencia,
        titulo: 'Evidencia ${e.tipo}',
        descripcion: _descripcionEvidencia(e),
        estado: e.metadata.estado,
        estadoVisual: _visualDeMetadata(e.metadata),
        usuarioId: e.usuarioId,
        intentos: e.metadata.intentos,
        creadaEn: e.creadaEn,
        proximoIntento: e.metadata.proximoIntento,
        ultimoError: e.metadata.ultimoError,
        codigoError: e.metadata.ultimoCodigo,
        ultimoStatus: e.metadata.ultimoStatus,
        requiereLogin: e.metadata.requiereLogin,
        idempotencyKey: e.metadata.idempotencyKey,
        archivos: e.fotoPaths
            .map(
              (p) => ArchivoSincronizacionView(ruta: p, verificado: true),
            )
            .toList(),
        dependencias: [
          if (e.folioId != null)
            DependenciaSincronizacionView(
              idLocal: e.folioId!,
              tipo: TipoOperacionOffline.solicitud,
              descripcion: 'Folio ${e.folioId}',
            ),
        ],
        puedeReintentar: _puedeReintentar(e.metadata),
        requiereAtencion: _requiereAtencion(e.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de recorridos marimba en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasRecorridosMarimba(
    List<RecorridoMarimbaPendienteOffline> items,
  ) {
    return items.map((r) {
      return OperacionSincronizacionView(
        idLocal: r.idLocal,
        idServer: r.idServidor,
        tipo: TipoOperacionOffline.recorridoMarimba,
        titulo: 'Recorrido marimba',
        descripcion: _descripcionRecorridoMarimba(r),
        estado: r.metadata.estado,
        estadoVisual: _visualDeMetadata(r.metadata),
        usuarioId: r.usuarioId,
        intentos: r.metadata.intentos,
        creadaEn: r.creadaEn,
        proximoIntento: r.metadata.proximoIntento,
        ultimoError: r.metadata.ultimoError,
        codigoError: r.metadata.ultimoCodigo,
        ultimoStatus: r.metadata.ultimoStatus,
        requiereLogin: r.metadata.requiereLogin,
        idempotencyKey: r.metadata.idempotencyKey,
        archivos: const [],
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: r.marimbaId,
            tipo: TipoOperacionOffline.recorridoMarimba,
            descripcion: 'Marimba ${r.marimbaId}',
          ),
        ],
        puedeReintentar: _puedeReintentar(r.metadata),
        requiereAtencion: _requiereAtencion(r.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de despachos marimba en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasDespachosMarimba(
    List<DespachoMarimbaPendienteOffline> items,
  ) {
    return items.map((d) {
      return OperacionSincronizacionView(
        idLocal: d.idLocal,
        tipo: TipoOperacionOffline.despachoMarimba,
        titulo: 'Despacho marimba',
        descripcion: _descripcionDespachoMarimba(d),
        estado: d.metadata.estado,
        estadoVisual: _visualDeMetadata(d.metadata),
        usuarioId: d.usuarioId,
        intentos: d.metadata.intentos,
        creadaEn: d.creadaEn,
        proximoIntento: d.metadata.proximoIntento,
        ultimoError: d.metadata.ultimoError,
        codigoError: d.metadata.ultimoCodigo,
        ultimoStatus: d.metadata.ultimoStatus,
        requiereLogin: d.metadata.requiereLogin,
        idempotencyKey: d.metadata.idempotencyKey,
        archivos: _archivosDespacho(d),
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: d.recorridoIdLocal,
            tipo: TipoOperacionOffline.recorridoMarimba,
            descripcion: 'Recorrido padre',
          ),
          DependenciaSincronizacionView(
            idLocal: d.vehiculoDestinoId,
            tipo: TipoOperacionOffline.despachoMarimba,
            descripcion: 'Vehículo ${d.vehiculoDestinoId}',
          ),
        ],
        puedeReintentar: _puedeReintentar(d.metadata),
        requiereAtencion: _requiereAtencion(d.metadata),
      );
    }).toList();
  }

  /// Convierte una cola de cierres de recorrido marimba en vistas unificadas.
  static List<OperacionSincronizacionView> _vistasCierresMarimba(
    List<CierreRecorridoMarimbaPendienteOffline> items,
  ) {
    return items.map((c) {
      return OperacionSincronizacionView(
        idLocal: c.idLocal,
        tipo: TipoOperacionOffline.cierreRecorridoMarimba,
        titulo: 'Cierre recorrido',
        descripcion: _descripcionCierreMarimba(c),
        estado: c.metadata.estado,
        estadoVisual: _visualDeMetadata(c.metadata),
        usuarioId: c.usuarioId,
        intentos: c.metadata.intentos,
        creadaEn: c.creadaEn,
        proximoIntento: c.metadata.proximoIntento,
        ultimoError: c.metadata.ultimoError,
        codigoError: c.metadata.ultimoCodigo,
        ultimoStatus: c.metadata.ultimoStatus,
        requiereLogin: c.metadata.requiereLogin,
        idempotencyKey: c.metadata.idempotencyKey,
        archivos: _archivosCierre(c),
        dependencias: [
          DependenciaSincronizacionView(
            idLocal: c.recorridoIdLocal,
            tipo: TipoOperacionOffline.recorridoMarimba,
            descripcion: 'Recorrido padre',
          ),
        ],
        puedeReintentar: _puedeReintentar(c.metadata),
        requiereAtencion: _requiereAtencion(c.metadata),
      );
    }).toList();
  }

  /// Punto de entrada principal: convierte todas las colas a vistas unificadas.
  static CentroSincronizacionData agregar({
    required List<SolicitudPendienteOffline> solicitudes,
    required List<ComprobarCargaPendienteOffline> cargas,
    required List<CerrarDiaPendienteOffline> cierres,
    required List<IncidenciaPendienteOffline> incidencias,
    required List<EvidenciaPendienteOffline> evidencias,
    required List<RecorridoMarimbaPendienteOffline> recorridos,
    required List<DespachoMarimbaPendienteOffline> despachos,
    required List<CierreRecorridoMarimbaPendienteOffline> cierresRecorrido,
  }) {
    final todas = [
      ..._vistasSolicitudes(solicitudes),
      ..._vistasComprobarCarga(cargas),
      ..._vistasCerrarDia(cierres),
      ..._vistasIncidencias(incidencias),
      ..._vistasEvidencias(evidencias),
      ..._vistasRecorridosMarimba(recorridos),
      ..._vistasDespachosMarimba(despachos),
      ..._vistasCierresMarimba(cierresRecorrido),
    ];

    // Ordenar: primero los que requieren atención, luego por fecha descendente
    todas.sort((a, b) {
      if (a.requiereAtencion && !b.requiereAtencion) return -1;
      if (!a.requiereAtencion && b.requiereAtencion) return 1;
      return b.creadaEn.compareTo(a.creadaEn);
    });

    final conteoPorEstado = <EstadoVisualSincronizacion, int>{};
    var requiereAtencion = 0;
    var reintentables = 0;
    for (final op in todas) {
      conteoPorEstado[op.estadoVisual] =
          (conteoPorEstado[op.estadoVisual] ?? 0) + 1;
      if (op.requiereAtencion) requiereAtencion++;
      if (op.puedeReintentar) reintentables++;
    }

    return CentroSincronizacionData(
      operaciones: todas,
      conteoPorEstado: conteoPorEstado,
      total: todas.length,
      requiereAtencion: requiereAtencion,
      reintentables: reintentables,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  static EstadoVisualSincronizacion _visualDeMetadata(
    MetadataOperacionOffline m,
  ) {
    final ahora = DateTime.now();
    switch (m.estado) {
      case EstadoOperacionOffline.pendiente:
        return EstadoVisualSincronizacion.pendiente;
      case EstadoOperacionOffline.sincronizando:
        return EstadoVisualSincronizacion.sincronizando;
      case EstadoOperacionOffline.errorTransitorio:
        if (m.proximoIntento != null && m.proximoIntento!.isAfter(ahora)) {
          return EstadoVisualSincronizacion.reintentoPendiente;
        }
        return EstadoVisualSincronizacion.errorTransitorio;
      case EstadoOperacionOffline.conflicto:
        return EstadoVisualSincronizacion.conflicto;
      case EstadoOperacionOffline.errorPermanente:
        return EstadoVisualSincronizacion.errorPermanente;
      case EstadoOperacionOffline.sincronizada:
        return EstadoVisualSincronizacion.completada;
      case EstadoOperacionOffline.requiereRevision:
        return EstadoVisualSincronizacion.requiereRevision;
    }
  }

  static bool _puedeReintentar(MetadataOperacionOffline m) {
    if (m.estado == EstadoOperacionOffline.sincronizando) return false;
    if (m.estado == EstadoOperacionOffline.sincronizada) return false;
    return m.estado != EstadoOperacionOffline.requiereRevision;
  }

  static bool _requiereAtencion(MetadataOperacionOffline m) {
    if (m.requiereLogin) return true;
    return m.estado == EstadoOperacionOffline.errorPermanente ||
        m.estado == EstadoOperacionOffline.requiereRevision;
  }

  /// Mapea [EstadoSolicitudOffline] a [EstadoOperacionOffline] para el
  /// modelo de vista unificado (mismo criterio que `_estadoComun` en
  /// `cola_solicitudes_offline.dart`).
  static EstadoOperacionOffline _mapearEstadoSolicitud(
    EstadoSolicitudOffline estado,
  ) {
    switch (estado) {
      case EstadoSolicitudOffline.pendiente:
        return EstadoOperacionOffline.pendiente;
      case EstadoSolicitudOffline.sincronizando:
        return EstadoOperacionOffline.sincronizando;
      case EstadoSolicitudOffline.enviadaSinConfirmar:
        return EstadoOperacionOffline.errorTransitorio;
      case EstadoSolicitudOffline.requiereReintento:
        return EstadoOperacionOffline.errorTransitorio;
      case EstadoSolicitudOffline.sincronizada:
        return EstadoOperacionOffline.sincronizada;
      case EstadoSolicitudOffline.fallidaPermanente:
        return EstadoOperacionOffline.errorPermanente;
      case EstadoSolicitudOffline.requiereRevision:
        return EstadoOperacionOffline.requiereRevision;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers de descripción por tipo
  // ---------------------------------------------------------------------------

  static String _descripcionSolicitud(SolicitudPendienteOffline s) {
    final partes = <String>[
      '${s.litrosSolicitados.toStringAsFixed(1)}L',
      s.actividad,
    ];
    if (s.esUrgente) partes.add('Urgente');
    return partes.join(' · ');
  }

  static String _descripcionComprobarCarga(ComprobarCargaPendienteOffline c) {
    return '${c.litrosCargados.toStringAsFixed(1)}L · ${c.gasolinera}';
  }

  static String _descripcionCerrarDia(CerrarDiaPendienteOffline c) {
    return 'KM ${c.kmFinal.toStringAsFixed(1)}';
  }

  static String _descripcionEvidencia(EvidenciaPendienteOffline e) {
    final partes = <String>[];
    if (e.notas != null && e.notas!.isNotEmpty) {
      partes.add(e.notas!);
    }
    if (e.tipoCombustibleCargado != null) {
      partes.add(e.tipoCombustibleCargado!);
    }
    if (e.litros != null) {
      partes.add('${e.litros!.toStringAsFixed(1)}L');
    }
    if (partes.isEmpty) partes.add('${e.fotoPaths.length} foto(s)');
    return partes.join(' · ');
  }

  static String _descripcionRecorridoMarimba(
    RecorridoMarimbaPendienteOffline r,
  ) {
    final partes = <String>[
      r.tipoCombustible,
      r.frente,
    ];
    if (r.kmInicio != null) {
      partes.add('KM ${r.kmInicio!.toStringAsFixed(1)}');
    }
    return partes.join(' · ');
  }

  static String _descripcionDespachoMarimba(
    DespachoMarimbaPendienteOffline d,
  ) {
    final partes = <String>[
      d.operadorTexto,
      '${d.litrosDeclarados?.toStringAsFixed(1) ?? '?'}L',
    ];
    if (d.observaciones != null && d.observaciones!.isNotEmpty) {
      partes.add(d.observaciones!);
    }
    return partes.join(' · ');
  }

  static String _descripcionCierreMarimba(
    CierreRecorridoMarimbaPendienteOffline c,
  ) {
    return 'Existencia ${c.existenciaFisica.toStringAsFixed(1)}L';
  }

  // ---------------------------------------------------------------------------
  // Helpers de archivos
  // ---------------------------------------------------------------------------

  static List<ArchivoSincronizacionView> _archivosDeSolicitud(
    SolicitudPendienteOffline s,
  ) {
    final archivos = <ArchivoSincronizacionView>[];
    if (s.fotoTableroPath.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: s.fotoTableroPath, verificado: true),
      );
    }
    if (s.archivosOffline != null) {
      for (final a in s.archivosOffline!) {
        archivos.add(
          ArchivoSincronizacionView(
            storageKey: a.storageKey,
            sizeBytes: a.sizeBytes,
            sha256: a.sha256,
          ),
        );
      }
    }
    return archivos;
  }

  static List<ArchivoSincronizacionView> _archivosComunes(
    String? foto1,
    String? foto2,
  ) {
    final archivos = <ArchivoSincronizacionView>[];
    if (foto1 != null && foto1.isNotEmpty) {
      archivos.add(ArchivoSincronizacionView(ruta: foto1, verificado: true));
    }
    if (foto2 != null && foto2.isNotEmpty) {
      archivos.add(ArchivoSincronizacionView(ruta: foto2, verificado: true));
    }
    return archivos;
  }

  static List<ArchivoSincronizacionView> _archivosDespacho(
    DespachoMarimbaPendienteOffline d,
  ) {
    final archivos = <ArchivoSincronizacionView>[];
    if (d.fotoHorometroPath.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: d.fotoHorometroPath, verificado: true),
      );
    }
    if (d.fotoMedidorPath != null && d.fotoMedidorPath!.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: d.fotoMedidorPath!, verificado: true),
      );
    }
    if (d.fotoEvidenciaPath != null && d.fotoEvidenciaPath!.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: d.fotoEvidenciaPath!, verificado: true),
      );
    }
    if (d.archivosOffline != null) {
      for (final a in d.archivosOffline!) {
        archivos.add(
          ArchivoSincronizacionView(
            storageKey: a.storageKey,
            sizeBytes: a.sizeBytes,
            sha256: a.sha256,
          ),
        );
      }
    }
    return archivos;
  }

  static List<ArchivoSincronizacionView> _archivosCierre(
    CierreRecorridoMarimbaPendienteOffline c,
  ) {
    final archivos = <ArchivoSincronizacionView>[];
    if (c.fotoCierrePath.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: c.fotoCierrePath, verificado: true),
      );
    }
    if (c.fotoNivelPath.isNotEmpty) {
      archivos.add(
        ArchivoSincronizacionView(ruta: c.fotoNivelPath, verificado: true),
      );
    }
    if (c.archivosOffline != null) {
      for (final a in c.archivosOffline!) {
        archivos.add(
          ArchivoSincronizacionView(
            storageKey: a.storageKey,
            sizeBytes: a.sizeBytes,
            sha256: a.sha256,
          ),
        );
      }
    }
    return archivos;
  }
}
