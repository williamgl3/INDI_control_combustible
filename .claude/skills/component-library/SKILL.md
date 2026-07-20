---
name: component-library
description: "Usa esta skill antes de crear un botón, card, input, badge o cualquier componente visual nuevo. Antes de crear un widget desde cero, revisa aquí si ya existe uno equivalente en lib/widgets para reutilizarlo en vez de duplicar estilos."
---

# Librería de componentes compartidos

Ubicación real: **`lib/widgets/`** (no `core/widgets/`) — carpeta plana, sin
subcarpetas por feature. Todos siguen los tokens de la skill `design-system`
(`context.colors`, `context.shadows`, `AppRadii`, `AppSpacing`, `AppMotion`).

Antes de escribir un nuevo widget visual, revisa si ya existe uno de estos:

- `AppDialogShell` / `mostrarDialogoApp` (`app_dialog.dart`) — estructura
  compartida de TODO diálogo modal (`Dialog` con `boxShadow: raised`, radio
  `cardRadius`, padding `xxl`, `header` opcional a todo lo ancho). Úsalo para
  cualquier diálogo nuevo — no armes un `showDialog`/`Dialog` a mano, y
  no uses `showDialog` estándar para mantener la transición fade+scale de marca.
- `EstadoSolicitudBadge` (`estado_solicitud_badge.dart`) — pill de estado para
  `EstadoSolicitud` (pendiente/aprobada/rechazada). Para un nuevo enum de estado
  (como se hizo con `EstadoMantenimientoBadge`), crea un widget hermano con el
  mismo tratamiento visual (`Container` + `AppRadii.badgeRadius` + texto en
  mayúsculas w800) en vez de generalizar prematuramente un badge genérico.
- `ChipFiltro` (`chip_filtro.dart`) — chip de selección única para filtros
  (`ChoiceChip` estilizado), reutilizado en Concentrado, Mantenimiento, etc.
- `EstadoVacio` (`estado_vacio.dart`) — mensaje centrado + ícono opcional para
  listas/tablas sin datos. Es la ÚNICA implementación — no dupliques un
  `_EstadoVacio` privado por pantalla.
- `StatTile` (`stat_tile.dart`) — tarjeta compacta de una métrica (ícono +
  valor + etiqueta), usada en los headers de estadísticas de las pestañas admin.
- `BrandHeader` (`brand_header.dart`) — header navy plano (`colors.headerBackground`),
  usado en Login y en los "home" de chofer/administrativo.
- `CapturaFotoField` (`captura_foto_field.dart`) — botón de captura de foto con
  miniatura una vez tomada; delega la captura real a `FotoPicker` inyectado.
- `SelectorVehiculo` (`selector_vehiculo.dart`) — dropdown de vehículo/maquinaria
  con opción de reportar unidad nueva no catalogada.
- `BarraPresupuesto` (`barra_presupuesto.dart`) / `TarjetaTopeSemanal`
  (`tarjeta_tope_semanal.dart`) — barras de progreso con color semáforo
  (success/warning/error según proporción), usan `AppMotion.slow` en el
  `TweenAnimationBuilder` de revelado.
- `StepperNumerico` (`stepper_numerico.dart`) — input numérico grande con
  botones +/- y edición manual por toque, para capturar litros/km/horas en campo.
- `fecha_formato.dart` — `formatearFechaCorta`/`formatearDiaMes`, funciones (no
  widgets) para formatear fechas sin depender de `intl`.

## Regla al crear un widget nuevo
Si necesitas un componente que no está en esta lista: créalo en `lib/widgets/`
(archivo `snake_case.dart`, clase `PascalCase` sin sufijo salvo que aplique un
sufijo semántico como `Badge`/`Tile`/`Field`), sigue los tokens de
`design-system`, y agrégalo a esta lista actualizando este mismo archivo.

Para pantallas/diálogos específicos de una sola feature (ej. `RegistrarServicioDialog`,
`EditarVehiculoDialog`) NO es necesario promoverlos a `lib/widgets/` — viven
junto a su pantalla en `lib/screens/<feature>/` (ver skill `flutter-conventions`)
y solo se documentan aquí si terminan reutilizándose en más de una pantalla.
