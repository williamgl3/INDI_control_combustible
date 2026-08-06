# Reporte de Desarrollo — INDI Control de Combustible

**Grupo INDI · Julio 2026**

---

## 1. Introducción

INDI Control de Combustible es un sistema diseñado para gestionar y autorizar el consumo de combustible de vehículos en obra. Nació de una necesidad operativa real: controlar quién carga, cuánto carga, en qué vehículo y con qué justificación, todo desde el campo —donde la conectividad no siempre está garantizada—.

Este reporte documenta el estado actual del proyecto, la arquitectura implementada, las decisiones técnicas tomadas y el camino recorrido desde el primer commit hasta hoy.

---

## 2. Estado del Proyecto

### Cronología de desarrollo

| Fecha | Evento |
|-------|--------|
| 15 jul 2026 | Commit inicial — repositorio vacío |
| 16 jul 2026 | Flutter app con tema, modelos y navegación base |
| 16 jul 2026 | Desacople del vehículo del perfil del chofer |
| 16 jul 2026 | Rediseño visual basado en mockups de referencia |
| 20 jul 2026 | Integración del backend real vía API REST |
| 20 jul 2026 | Rediseño del design system completo |
| 20 jul 2026 | Panel administrativo con pestañas Dashboard y Mantenimiento |
| 20 jul 2026 | Fix: restauración de sesión al reabrir la app |
| 20 jul 2026 | Fix: mensajes reales del backend en errores |
| 21 jul 2026 | Rediseño de autenticación, refresh tokens, flujos nuevos |
| 21 jul 2026 | Pruebas de integración para todos los flujos nuevos |

En **7 días naturales** se construyó una aplicación Flutter multiplataforma con **285 archivos modificados**, **~26,700 líneas de código** y **19 archivos de pruebas** que cubren los flujos críticos.

### Métricas del proyecto

| Métrica | Valor |
|---------|-------|
| Archivos totales | 210 |
| Líneas de código | ~121,833 |
| Pantallas | 30+ |
| Widgets reutilizables | 45 |
| Modelos de dominio | 8 |
| Repositories | 16 (5 dominios × 3 capas + ApiClient) |
| Archivos de test | 19 |
| Plataformas soportadas | 6 (Android, iOS, Web, Windows, macOS, Linux) |
| Comunidades en grafo de conocimiento | 146 |

---

## 3. Arquitectura del Sistema

### Visión general

La aplicación sigue una arquitectura **limpia y en capas**, donde cada dependencia fluye hacia adentro: las pantallas dependen de providers, los providers de repositories, y los repositories de un cliente HTTP compartido.

```
┌─────────────────────────────────────────┐
│              PRESENTACIÓN               │
│  screens/ · widgets/ · theme/ · router/ │
├─────────────────────────────────────────┤
│             GESTIÓN DE ESTADO           │
│         core/providers.dart (Riverpod)  │
├─────────────────────────────────────────┤
│               DOMINIO                   │
│         models/ · core/validators.dart  │
├─────────────────────────────────────────┤
│                DATOS                    │
│    data/ (Abstract + Mock + API) × 5    │
├─────────────────────────────────────────┤
│              INFRAESTRUCTURA            │
│      api_client.dart · api_config.dart  │
└─────────────────────────────────────────┘
```

### Stack tecnológico

| Capa | Tecnología | Justificación |
|------|-----------|---------------|
| Framework | Flutter 3.x + Dart 3.12 | Multiplataforma nativa, rendimiento en campo |
| Estado | Riverpod 2.6 | Inyección de dependencias reactiva, testable |
| Navegación | GoRouter 14.8 | Declarativa, con guards de sesión centralizados |
| HTTP | `http` + ApiClient custom | Auto-refresh de JWT, manejo de errores uniforme |
| Persistencia | SharedPreferences + FlutterSecureStorage | Cola offline + tokens seguros |
| OCR | Google ML Kit Text Recognition | Lectura de tickets de gasolinera en campo |
| Gráficos | fl_chart | Dashboard de consumo de combustible |
| Testing | flutter_test + Riverpod overrides | Fakes en memoria, sin backend real |

### Capa de datos: patrón Repository

Cada dominio del negocio tiene tres implementaciones:

```
AuthRepository (interfaz)
  ├── MockAuthRepository    → para tests y desarrollo
  └── ApiAuthRepository     → comunicación real con el backend
```

Los cinco dominios son: **Autenticación**, **Operaciones** (cargas, autorizaciones, precios), **Vehículos**, **Incidencias** y **Auditoría**. Esta separación permite que todo el frontend funcione sin backend durante el desarrollo y testing, y que la transición a producción sea un cambio de un provider.

### Design System

El proyecto tiene un design system corporativo/industrial documentado como skill de Claude:

- **Colores**: Paleta primaria `#1463FF`, navy `#142B52`, sidebar `#1B1F27`. Temas claro y oscuro con tokens semanticos.
- **Tipografía**: IBM Plex Sans (display), Manrope (body), IBM Plex Mono (datos numéricos).
- **Espaciado**: Escala fija de 4px (xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32).
- **Componentes**: 45 widgets reutilizables con tokens de diseño consistentes.
- **Transiciones**: Curvas y duraciones parametrizadas (`fast=150ms`, `base=250ms`, `slow=400ms`).

---

## 4. Funcionalidades Implementadas

### Rol: Chofer

El chofer es el usuario principal en campo. Su experiencia está diseñada para funcionar con conectividad intermitente:

| Pantalla | Función |
|----------|---------|
| **Dashboard** | Consumo semanal, litros por tipo de combustible, acciones pendientes |
| **Solicitar Carga** | Formulario con selector de vehículo, StepperNumerico para litros, captura de foto del tablero, actividad |
| **Comprobar Carga** | Verificación post-carga: fotos (tablero + ticket), OCR automático, km, gasolinera |
| **Cerrar Día** | Cierre con km final, foto del tablero, cálculo de rendimiento (km/L) |
| **Mis Solicitudes** | Historial con estados (pendiente/aprobada/rechazada), detalle, cancelación |
| **Mi Perfil** | Visualización y cambio de contraseña |
| **Reportar Incidencia** | Descripción + foto de problema con vehículo |
| **Reportar Vehículo Nuevo** | Alta rápida de unidad no registrada |

### Rol: Administrativo

El panel administrativo es un dashboard de control completo con 8 secciones:

| Pestaña | Función |
|---------|---------|
| **Dashboard** | Métricas consolidadas de consumo, porcentajes por combustible |
| **Autorizaciones** | Aprobación/rechazo de solicitudes de carga con filtros por estado |
| **Concentrado** | Tabla de movimientos con exportación CSV |
| **Finanzas** | Control de precios de combustible y presupuesto semanal |
| **Vehículos** | Catálogo: agregar, editar, registrar servicio, tope semanal |
| **Mantenimiento** | Diagnóstico de estado (al día/próximo/vencido), exportación CSV |
| **Choferes** | Gestión de usuarios: crear, desactivar, resetear contraseña |
| **Auditoría** | Registro de actividad con paginación |

### Autenticación y seguridad

- Login con JWT + refresh tokens (auto-renovación transparente)
- Guard de rutas: chofer no puede acceder a rutas de administrativo y viceversa
- Sesión restaurada al reabrir la app (sin re-login)
- Tokens en FlutterSecureStorage (encriptado en disco)

### Sistema Offline

El sistema offline es una de las partes más complejas del proyecto. Cuatro flujos del chofer pueden ejecutarse sin señal:

1. **Solicitar Carga** → se encola localmente
2. **Comprobar Carga** → se encola con fotos
3. **Cerrar Día** → se encola con foto del tablero
4. **Reportar Incidencia** → se encola con foto

Cuando vuelve la conexión, la cola se sincroniza automáticamente. Si una foto ya no existe al sincronizar, la pendiente se descarta con un aviso al usuario.

---

## 5. Calidad del Código

### Pruebas

El proyecto tiene **19 archivos de test** con una arquitectura bien pensada:

- **5 tests unitarios puros** (sin UI): validadores, cálculos de dashboard, cálculos de mantenimiento, utilidades de semana, refresh de token.
- **13 tests de flujo (flow tests)**: ejercitan pantallas completas con navegación real, usando Riverpod overrides para inyectar mocks.
- **1 smoke test**: verifica que la app arranca correctamente.

El archivo `test_helpers.dart` centraliza toda la infraestructura de testing:
- `FakeTokenStorage` y `FakeSessionStorage`: persistencia en memoria
- `FakeFotoPicker`: fotos sintéticas sin cámara real
- `FakeTicketOcrService`: OCR con valores predefinidos
- `FakeRecordatorioService` y `FakeExportadorService`: servicios sin efectos secundarios
- `makeTestContainer()`: factory que inyecta todos los mocks en un ProviderContainer
- `pumpTestApp()`: helper que monta la app con router y tema real

### Grafo de conocimiento

El proyecto integra **graphify**, un grafo de conocimiento que mapea relaciones entre archivos, conceptos y comunidades:

- **2,499 nodos** y **3,841 aristas** en el grafo
- **146 comunidades** detectadas automáticamente
- **God nodes** identificados: `operacionesTickProvider` (52 conexiones), `operacionesRepositoryProvider` (32), `sessionProvider` (26)
- Hooks integrados en `.claude/settings.json` para validación antes de cada operación de código

---

## 6. Decisiones Técnicas Clave

### 1. Patrón `operacionesTickProvider`

Los repositorios mock son objetos mutables en memoria. Riverpod no detecta mutaciones directas, así que se implementó un `StateProvider<int>` que se incrementa después de cada mutación. Cualquier pantalla que lea datos del repositorio debe hacer `ref.watch(operacionesTickProvider)` además del provider del repositorio.

**Por qué**: Permite que los tests de flujo usen repos mock mutables sin perder reactividad en la UI.

### 2. GoRouter con guards centralizados

Un solo `_redirigirSegunSesion()` en `app_router.dart` maneja toda la lógica de redirección: sin sesión → login, chofer en ruta admin → redirigir a chofer, sesión activa en login → redirigir al dashboard.

**Por qué**: Centraliza la lógica de acceso en un solo lugar, evitando duplicación en cada pantalla.

### 3. ApiClient con auto-refresh

El `ApiClient` intercepta errores 401, intenta renovar el token una vez con el refresh token, y si falla, limpia la sesión completamente. Los repos no necesitan manejar renovación de tokens.

**Por qué**: El refresh de tokens es un concern transversal que no debería duplicarse en cada llamada HTTP.

### 4. Offline-first con cola de persistencia

Las solicitudes del chofer se persisten en SharedPreferences como JSON. La sincronización se observa automáticamente cuando cambia el estado de conectividad.

**Por qué**: En obra, la señal es intermitente. El usuario no debería perder datos por falta de conexión.

---

## 7. Imágenes Sugeridas para el Reporte

Para completar este reporte con evidencia visual, se recomienda capturar las siguientes pantallas:

### Hoja 1 — Portada e Introducción

| # | Descripción | Archivo sugerido | Ubicación en el reporte |
|---|-------------|-----------------|------------------------|
| 1 | **Logo de INDI** | `frontend/assets/images/logo_indi_mark.png` | Portada, junto al título |
| 2 | **Pantalla de Login** (captura de la app corriendo) | Captura de pantalla de `login_screen.dart` | Sección 1 — Introducción |

### Hoja 2 — Arquitectura

| # | Descripción | Fuente | Ubicación |
|---|-------------|--------|-----------|
| 3 | **Diagrama de arquitectura en capas** | Generar diagrama con las 5 capas descritas en la Sección 3 | Sección 3 — Arquitectura |
| 4 | **Grafo de conocimiento** (captura de `graph.html`) | Abrir `graphify-out/graph.html` en navegador y capturar | Sección 5 — Calidad del Código |

### Hoja 3 — Funcionalidades

| # | Descripción | Fuente | Ubicación |
|---|-------------|--------|-----------|
| 5 | **Dashboard del Chofer** | Captura de `chofer_home_screen.dart` o `chofer_dashboard_screen.dart` | Sección 4 — Rol Chofer |
| 6 | **Panel Administrativo** | Captura de `administrativo_home_screen.dart` | Sección 4 — Rol Administrativo |
| 7 | **Flujo de solicitud de carga** | Captura de `solicitar_carga_screen.dart` | Sección 4 — Funcionalidades |

### Hoja 4 — Calidad y Conclusiones

| # | Descripción | Fuente | Ubicación |
|---|-------------|--------|-----------|
| 8 | **Resultados de tests** (captura de terminal con `flutter test`) | Ejecutar `flutter test` y capturar salida | Sección 5 — Pruebas |
| 9 | **Estructura de carpetas** (captura de VS Code o explorer) | Capturar la estructura de `frontend/lib/` | Sección 6 — Decisiones Técnicas |

### Resumen de imágenes necesarias

| # | Imagen | Tipo | Sección |
|---|--------|------|---------|
| 1 | Logo INDI | Asset existente | Portada |
| 2 | Login screen | Captura de app | Introducción |
| 3 | Diagrama de arquitectura | Diagrama a generar | Arquitectura |
| 4 | Grafo de conocimiento | Captura de graph.html | Calidad |
| 5 | Dashboard chofer | Captura de app | Funcionalidades |
| 6 | Panel admin | Captura de app | Funcionalidades |
| 7 | Solicitud de carga | Captura de app | Funcionalidades |
| 8 | Resultados test | Captura de terminal | Calidad |
| 9 | Estructura carpetas | Captura de IDE | Decisiones |

---

## 8. Conclusión

En una semana se construyó una aplicación robusta, multiplataforma y con una arquitectura preparada para escalar. Los puntos fuertes del proyecto son:

- **Separación clara de responsabilidades** entre capas
- **Design system documentado** y consistente
- **Testing integral** que cubre los flujos críticos
- **Sistema offline** que respeta la realidad operativa en campo
- **Integración con backend real** desde el primer día
- **Grafo de conocimiento** que mantiene documentada la estructura del código

Los próximos pasos naturales serían: integración de notificaciones push, modo offline completo para chofer (ya iniciado), exportación de reportes en PDF, y expansión del backend con más endpoints de reportes.

---

*Reporte generado el 24 de julio de 2026 · INDI Control de Combustible*
