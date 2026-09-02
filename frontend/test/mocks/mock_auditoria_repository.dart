import 'package:indi_combustible/data/auditoria_repository.dart';
import 'package:indi_combustible/models/registro_auditoria.dart';

/// Repositorio de auditoría MOCK — datos de ejemplo variados en memoria,
/// para widget tests y como referencia de la interfaz que implementa
/// `ApiAuditoriaRepository`.
class MockAuditoriaRepository implements AuditoriaRepository {
  MockAuditoriaRepository() {
    final ahora = DateTime.now();
    _todos = [
      RegistroAuditoria(
        id: 'aud-1',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'aprobó',
        entidad: 'solicitud_autorizacion',
        entidadId: 'sol-1001',
        detalle: 'Autorizó 40 L de los 45 L solicitados.',
        creadoEn: ahora.subtract(const Duration(minutes: 12)),
      ),
      RegistroAuditoria(
        id: 'aud-2',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'editó',
        entidad: 'vehiculo',
        entidadId: 'veh-3',
        detalle: 'Cambió el tope semanal de 200 L a 250 L.',
        creadoEn: ahora.subtract(const Duration(hours: 2)),
      ),
      RegistroAuditoria(
        id: 'aud-3',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'resolvió',
        entidad: 'incidencia_vehiculo',
        entidadId: 'inc-7',
        detalle: 'Llanta ponchada — se cambió por refacción en almacén.',
        creadoEn: ahora.subtract(const Duration(hours: 5)),
      ),
      RegistroAuditoria(
        id: 'aud-4',
        usuarioId: 'mock-admin-2',
        usuarioNombre: 'Carlos Ruiz',
        accion: 'desactivó',
        entidad: 'usuario',
        entidadId: 'mock-chofer-3',
        detalle: 'Baja temporal por término de contrato.',
        creadoEn: ahora.subtract(const Duration(days: 1, hours: 1)),
      ),
      RegistroAuditoria(
        id: 'aud-5',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'rechazó',
        entidad: 'solicitud_autorizacion',
        entidadId: 'sol-998',
        detalle: 'Excede el presupuesto semanal restante.',
        creadoEn: ahora.subtract(const Duration(days: 1, hours: 4)),
      ),
      RegistroAuditoria(
        id: 'aud-6',
        usuarioId: 'mock-admin-2',
        usuarioNombre: 'Carlos Ruiz',
        accion: 'activó',
        entidad: 'usuario',
        entidadId: 'mock-chofer-2',
        detalle: 'Reincorporación tras permiso.',
        creadoEn: ahora.subtract(const Duration(days: 2)),
      ),
      RegistroAuditoria(
        id: 'aud-7',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'creó',
        entidad: 'vehiculo',
        entidadId: 'veh-9',
        detalle: 'Alta de nueva retroexcavadora.',
        creadoEn: ahora.subtract(const Duration(days: 3)),
      ),
      RegistroAuditoria(
        id: 'aud-8',
        usuarioId: 'mock-admin-2',
        usuarioNombre: 'Carlos Ruiz',
        accion: 'reseteó contraseña de',
        entidad: 'usuario',
        entidadId: 'mock-chofer-1',
        detalle: 'Solicitado por el chofer vía WhatsApp.',
        creadoEn: ahora.subtract(const Duration(days: 4)),
      ),
      RegistroAuditoria(
        id: 'aud-9',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'editar_precio',
        entidad: 'precio_combustible',
        entidadId: 'Diésel',
        detalle: const {'nuevoPrecio': 26.9},
        creadoEn: ahora.subtract(const Duration(minutes: 30)),
      ),
      RegistroAuditoria(
        id: 'aud-10',
        usuarioId: 'mock-admin-1',
        usuarioNombre: 'Ana Torres',
        accion: 'editar_presupuesto_semanal',
        entidad: 'configuracion',
        entidadId: 'presupuesto_semanal_total',
        detalle: const {'nuevoValor': 60000},
        creadoEn: ahora.subtract(const Duration(hours: 1)),
      ),
      RegistroAuditoria(
        id: 'aud-11',
        usuarioId: 'mock-admin-2',
        usuarioNombre: 'Carlos Ruiz',
        accion: 'editar_carga',
        entidad: 'carga',
        entidadId: 'carga-55',
        detalle: const {
          'anterior': {'litrosCargados': 38.0, 'kmAlCargar': 1000.0},
          'nuevo': {'litrosCargados': 40.0, 'kmAlCargar': 1005.0},
        },
        creadoEn: ahora.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  late List<RegistroAuditoria> _todos;
  List<RegistroAuditoria> _registros = [];
  bool _sinMasRegistros = false;

  @override
  List<RegistroAuditoria> get registros => List.unmodifiable(_registros);

  @override
  bool get sinMasRegistros => _sinMasRegistros;

  @override
  Future<void> cargarRegistros({int limit = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _registros = _todos.take(limit).toList();
    _sinMasRegistros = _registros.length >= _todos.length;
  }

  @override
  Future<void> cargarMasRegistros({int limit = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_registros.isEmpty) {
      return cargarRegistros(limit: limit);
    }
    final restantes = _todos.skip(_registros.length).take(limit).toList();
    _registros = [..._registros, ...restantes];
    _sinMasRegistros = _registros.length >= _todos.length;
  }
}
