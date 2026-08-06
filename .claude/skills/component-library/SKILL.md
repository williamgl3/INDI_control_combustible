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
- `fecha_formato.dart` — `formatearFechaCorta`/`formatearDiaMes`/`formatearFecha`/
  `formatearHora`/`etiquetaGrupoFecha`/`agruparPorFecha`, funciones (no widgets)
  para formatear y agrupar por fecha sin depender de `intl`.
- `TarjetaAccionSugerida` (`tarjeta_accion_sugerida.dart`) — tarjeta de "hay algo
  que te conviene hacer ahora" (ícono + color + título + subtítulo + chevron,
  tappable). Úsala para cualquier CTA contextual tipo "carga aprobada por
  comprobar"/"día por cerrar" en vez de una card ad hoc por caso.
- `SinConexionDialog` (`sin_conexion_dialog.dart`) — diálogo de "se guardó
  localmente, se enviará solo al reconectar" para las colas offline. Llama
  `SinConexionDialog.show(context, mensaje: '...')` en vez de armar un
  `AlertDialog` a mano.
- `AvisoError` (`aviso_error.dart`) — mensaje de error de validación/envío con
  ícono + contenedor de color (mismo tratamiento que los avisos de éxito/OCR),
  en vez del texto rojo plano sin ícono que se repetía por pantalla.
- `CeldaEditable` (`celda_editable.dart`) — celda numérica editable "en el
  lugar" estilo hoja de cálculo: texto con pista visual sutil de que es
  editable, al tocarla se vuelve `TextField`, confirma con Enter/blur y
  llama `onGuardar`. Úsala para cualquier valor editable inline (precio,
  presupuesto, litros, km) en vez de abrir un diálogo modal para un solo
  campo.
- `FiltroColumnaBoton<T>` (`filtro_columna_boton.dart`) — ícono de filtro
  por columna (como el de un encabezado de Excel) que abre una hoja con
  casillas + buscador; el ícono se rellena de color cuando el filtro está
  activo. Úsalo en encabezados de tabla en vez de un dropdown nativo.
- `formato_numero.dart` — `formatearMoneda`/`formatearMonedaDecimal`/
  `formatearNumero`/`formatearNumeroConDecimales`, funciones (no widgets)
  con separador de miles (`es_MX`, vía `intl`) para dinero/cantidades — no
  volver a armar `'\$${valor.toStringAsFixed(0)}'` a mano.
- `AppElevatedButton` (`app_elevated_button.dart`) — `ElevatedButton` primario
  con estado de carga incorporado (spinner + deshabilitado mientras
  `cargando: true`). Pasa `onPressed` SIN el null-guard manual (`cargando ?
  null : accion`) — el widget ya lo hace. Úsalo para cualquier botón primario
  de envío de formulario en vez de repetir el `SizedBox`+`CircularProgressIndicator`
  a mano.

## Regla al crear un widget nuevo
Si necesitas un componente que no está en esta lista: créalo en `lib/widgets/`
(archivo `snake_case.dart`, clase `PascalCase` sin sufijo salvo que aplique un
sufijo semántico como `Badge`/`Tile`/`Field`), sigue los tokens de
`design-system`, y agrégalo a esta lista actualizando este mismo archivo.

Para pantallas/diálogos específicos de una sola feature (ej. `RegistrarServicioDialog`,
`EditarVehiculoDialog`) NO es necesario promoverlos a `lib/widgets/` — viven
junto a su pantalla en `lib/screens/<feature>/` (ver skill `flutter-conventions`)
y solo se documentan aquí si terminan reutilizándose en más de una pantalla.
