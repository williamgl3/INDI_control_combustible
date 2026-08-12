import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session_provider.dart';
import '../core/catalogos_vehiculo.dart';
import '../core/capacidades_rol.dart';
import '../models/carga.dart';
import '../models/perfil.dart';
import '../models/solicitud_autorizacion.dart';
import '../screens/administrativo/administrativo_home_screen.dart';
import '../screens/administrativo/chofer_detalle_screen.dart';
import '../screens/bienvenida/bienvenida_screen.dart';
import '../screens/chofer/cerrar_dia_screen.dart';
import '../screens/chofer/chofer_dashboard_screen.dart';
import '../screens/chofer/chofer_home_shell.dart';
import '../screens/chofer/comprobar_carga_screen.dart';
import '../screens/chofer/mi_perfil_screen.dart';
import '../screens/chofer/mis_solicitudes_screen.dart';
import '../screens/chofer/respuesta_solicitud_screen.dart';
import '../screens/chofer/solicitar_carga_screen.dart';
import '../screens/chofer/subir_evidencias_screen.dart';
import '../screens/chofer/recorrido_marimba_screen.dart';
import '../screens/chofer/tipo_operacion_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/recuperar_password/recuperar_password_screen.dart';
import '../screens/registro_chofer/registro_chofer_screen.dart';
import '../theme/app_motion.dart';
import 'placeholder_screen.dart';
import 'route_paths.dart';

/// Transición fade + slide sutil compartida por todas las rutas, para que
/// la navegación se sienta consistente en vez del slide por defecto de la
/// plataforma.
CustomTransitionPage<void> _conTransicion(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.base,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curva,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curva),
          child: child,
        ),
      );
    },
  );
}

/// Notifica a GoRouter cuando cambia la sesión, para que reevalúe el
/// guard de rutas (`redirect`) sin necesidad de navegación manual.
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(Ref ref) {
    ref.listen<Perfil?>(sessionProvider, (previous, next) => notifyListeners());
  }
}

/// Guard de sesión centralizado. Decide, para cada intento de navegación,
/// si debe redirigir a otra ruta según si hay sesión y el rol del perfil.
///
/// Devuelve `null` si no hace falta redirigir.
String? _redirigirSegunSesion(Perfil? perfil, GoRouterState state) {
  final destino = state.matchedLocation;
  final esPublica = RoutePaths.publicas.contains(destino);

  if (perfil == null) {
    // Sin sesión: solo se permite ver rutas públicas.
    return esPublica ? null : RoutePaths.bienvenida;
  }

  // Con sesión: no debe poder volver a login/registro/recuperar.
  // El supervisor opera la marimba con las mismas pantallas que un chofer
  // (solicitar/comprobar carga + su propia pantalla de despacho) — ver
  // `Perfil.esSupervisor`.
  final esDelPanelDeChofer = perfil.esChofer || perfil.esSupervisor;
  if (esPublica) {
    return esDelPanelDeChofer ? RoutePaths.chofer : RoutePaths.administrativo;
  }

  final esRutaDeChofer = destino.startsWith(RoutePaths.chofer);
  final esRutaDeAdministrativo = destino.startsWith(RoutePaths.administrativo);
  final esRutaExclusivaSupervisor =
      destino == RoutePaths.choferRegistrarDespacho ||
      destino == RoutePaths.choferRecorridoMarimba;
  if (destino == RoutePaths.choferSolicitar) {
    return RoutePaths.choferTipoOperacion;
  }
  if (destino.startsWith('${RoutePaths.choferSolicitar}/')) {
    final categoria = categoriaSolicitudDesdeRuta(
      state.pathParameters['categoria'],
    );
    if (categoria == null || !puedeSolicitarCategoria(perfil.rol, categoria)) {
      return RoutePaths.choferTipoOperacion;
    }
  }
  if (esRutaDeChofer && !esDelPanelDeChofer) {
    return RoutePaths.administrativo;
  }
  if (esRutaDeAdministrativo && !perfil.esAdministrativo) {
    return RoutePaths.chofer;
  }
  if (esRutaExclusivaSupervisor && !perfil.esSupervisor) {
    return RoutePaths.chofer;
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _SessionRefreshNotifier(ref);

  return GoRouter(
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final perfil = ref.read(sessionProvider);
      return _redirigirSegunSesion(perfil, state);
    },
    routes: [
      GoRoute(
        path: RoutePaths.bienvenida,
        pageBuilder: (context, state) =>
            _conTransicion(state, const BienvenidaScreen()),
      ),
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) =>
            _conTransicion(state, const LoginScreen()),
      ),
      GoRoute(
        path: RoutePaths.registroChofer,
        pageBuilder: (context, state) =>
            _conTransicion(state, const RegistroChoferScreen()),
      ),
      GoRoute(
        path: RoutePaths.recuperarPassword,
        pageBuilder: (context, state) =>
            _conTransicion(state, const RecuperarPasswordScreen()),
      ),
      GoRoute(
        path: RoutePaths.chofer,
        pageBuilder: (context, state) =>
            _conTransicion(state, const ChoferHomeShell()),
      ),
      GoRoute(
        path: RoutePaths.choferTipoOperacion,
        // Sin `ChoferMobileWrapper` — a diferencia de las demás rutas de
        // chofer, esta pantalla ya maneja su propio ancho responsivo
        // (sidebar + contenido, igual que `ChoferHomeShell`, que tampoco
        // lo usa a este nivel). Envolverla aquí encogía la pantalla
        // completa (sidebar y contenido juntos) a 480px, en vez de
        // dejar solo el contenido capado.
        pageBuilder: (context, state) =>
            _conTransicion(state, const TipoOperacionScreen()),
      ),
      GoRoute(
        path: RoutePaths.choferSolicitarConCategoria,
        // Sin `ChoferMobileWrapper` — igual que `choferTipoOperacion`, esta
        // pantalla ya maneja su propio ancho con `ContenidoResponsivo`.
        // Envolverla aquí anidaba dos `Center`/`ConstrainedBox` (el de
        // `ChoferMobileWrapper` a 720px + el propio de la pantalla), lo que
        // además rompía la apertura del menú de `SelectorVehiculo` en
        // pruebas de widget (el toque no llegaba a abrir el dropdown).
        pageBuilder: (context, state) {
          final categoria = categoriaSolicitudDesdeRuta(
            state.pathParameters['categoria'],
          );
          if (categoria == null) {
            return _conTransicion(
              state,
              RutaInvalidaScreen(
                onVolver: () => context.go(RoutePaths.choferTipoOperacion),
              ),
            );
          }
          return _conTransicion(
            state,
            SolicitarCargaScreen(categoria: categoria),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.choferSolicitar,
        redirect: (_, _) => RoutePaths.choferTipoOperacion,
      ),
      GoRoute(
        path: RoutePaths.choferRegistrarDespacho,
        redirect: (_, _) => RoutePaths.choferRecorridoMarimba,
      ),
      GoRoute(
        path: RoutePaths.choferRecorridoMarimba,
        pageBuilder: (context, state) =>
            _conTransicion(state, const RecorridoMarimbaScreen()),
      ),
      GoRoute(
        path: RoutePaths.choferRespuesta,
        pageBuilder: (context, state) {
          final solicitud = state.extra;
          if (solicitud is! SolicitudAutorizacion) {
            return _conTransicion(
              state,
              RutaInvalidaScreen(onVolver: () => context.go(RoutePaths.chofer)),
            );
          }
          return _conTransicion(
            state,
            RespuestaSolicitudScreen(solicitud: solicitud),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.choferComprobar,
        pageBuilder: (context, state) {
          final folio = state.extra;
          if (folio is! String) {
            return _conTransicion(
              state,
              RutaInvalidaScreen(onVolver: () => context.go(RoutePaths.chofer)),
            );
          }
          return _conTransicion(
            state,
            ComprobarCargaScreen(folioAutorizacion: folio),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.choferCerrarDia,
        pageBuilder: (context, state) {
          final carga = state.extra;
          if (carga is! Carga) {
            return _conTransicion(
              state,
              RutaInvalidaScreen(onVolver: () => context.go(RoutePaths.chofer)),
            );
          }
          return _conTransicion(state, CerrarDiaScreen(carga: carga));
        },
      ),
      GoRoute(
        path: RoutePaths.choferSolicitudes,
        // Ya trae su propio `SidebarChofer` + `ContenidoResponsivo` en su
        // rama standalone (ver `MisSolicitudesScreen.build`).
        pageBuilder: (context, state) =>
            _conTransicion(state, const MisSolicitudesScreen()),
      ),
      GoRoute(
        path: RoutePaths.choferPerfil,
        pageBuilder: (context, state) =>
            _conTransicion(state, const MiPerfilScreen()),
      ),
      GoRoute(
        path: RoutePaths.choferDashboard,
        pageBuilder: (context, state) =>
            _conTransicion(state, const ChoferDashboardScreen()),
      ),
      GoRoute(
        path: RoutePaths.choferSubirEvidencias,
        pageBuilder: (context, state) =>
            _conTransicion(state, const SubirEvidenciasScreen()),
      ),
      GoRoute(
        path: RoutePaths.administrativo,
        pageBuilder: (context, state) =>
            _conTransicion(state, const AdministrativoHomeScreen()),
      ),
      GoRoute(
        path: RoutePaths.administrativoChoferDetalle,
        pageBuilder: (context, state) {
          final chofer = state.extra;
          if (chofer is! Perfil) {
            return _conTransicion(
              state,
              RutaInvalidaScreen(
                onVolver: () => context.go(RoutePaths.administrativo),
              ),
            );
          }
          return _conTransicion(state, ChoferDetalleScreen(chofer: chofer));
        },
      ),
    ],
  );
});
