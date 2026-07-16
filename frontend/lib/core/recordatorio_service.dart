import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios locales (notificaciones programadas en el propio
/// dispositivo, sin backend) para que el chofer no olvide "cerrar su
/// día" (registro 2) después de cargar combustible (registro 1).
abstract class RecordatorioService {
  /// Programa el recordatorio de una [cargaId] para el momento [cuando].
  /// Si ya existía uno programado para esa carga, lo reemplaza.
  Future<void> programarRecordatorioCerrarDia({
    required String cargaId,
    required DateTime cuando,
  });

  /// Cancela el recordatorio de una carga (ej. porque ya se cerró el día).
  Future<void> cancelarRecordatorio(String cargaId);
}

class LocalRecordatorioService implements RecordatorioService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  Future<void> _inicializar() async {
    if (_inicializado) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const inicioAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const inicioIOS = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: inicioAndroid, iOS: inicioIOS),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _inicializado = true;
  }

  /// El id de la notificación se deriva del id de la carga para poder
  /// cancelarla después sin tener que recordar un id numérico aparte.
  int _idDe(String cargaId) => cargaId.hashCode & 0x7fffffff;

  @override
  Future<void> programarRecordatorioCerrarDia({
    required String cargaId,
    required DateTime cuando,
  }) async {
    await _inicializar();
    await _plugin.zonedSchedule(
      _idDe(cargaId),
      '¿Ya terminaste tu día?',
      'No olvides tomar la foto del tablero para cerrar tu jornada.',
      tz.TZDateTime.from(cuando, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cerrar_dia',
          'Cerrar mi día',
          channelDescription: 'Recordatorio para registrar el km final del día.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelarRecordatorio(String cargaId) async {
    await _plugin.cancel(_idDe(cargaId));
  }
}
