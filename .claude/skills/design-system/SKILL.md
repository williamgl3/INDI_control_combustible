---
name: design-system
description: "Usa esta skill siempre que crees o edites cualquier pantalla, widget o componente visual de la app. Contiene los tokens de diseño oficiales (colores, tipografía, espaciado, radios, sombras, transiciones) del tema corporativo/industrial de INDI Combustible. Ningún color, tamaño de fuente, radio o sombra debe hardcodearse fuera de estos valores."
---

# Sistema de diseño — INDI Combustible (corporativo/industrial)

Dirección visual aprobada por el usuario: acento azul de marca (logo INDI), header
navy sólido, sidebar oscuro neutro en el panel administrativo, cards grandes con
sombra visible (estilo tipo GooApps), botones primarios en píldora. Nada de
gradientes decorativos ni de un segundo color de acento para "admin" — el sidebar
oscuro ya cumple ese rol de distinción visual.

Todos los tokens viven como clases estáticas/`ThemeExtension` en `lib/theme/`.
Accede a ellos en widgets vía `context.colors` y `context.shadows` (extensión
`AppThemeContext` en `app_theme.dart`) — nunca hardcodees un hex suelto ni uses
`Theme.of(context).colorScheme` directo para estos valores.

## Colores (`AppColors`, `lib/theme/app_colors.dart`)
Tema claro (`AppColors.light`):
- `background`: `#F5F6F8`
- `surface`: `#FFFFFF`
- `surfaceAlt`: `#E6E9EE` (fondo de inputs, filas alternas, chips inactivos)
- `border`: `#C7CDD7`
- `textPrimary`: `#17202E`
- `textSecondary`: `#48546A`
- `textMuted`: `#5B6678` (cumple WCAG AA ~4.6:1 sobre blanco — no bajar el contraste)
- `primary`: `#1463FF` — botón primario, CTAs, ítem de sidebar activo, folios
- `primaryHover`: `#0F52D9`
- `primaryOn`: `#FFFFFF` (texto/ícono sobre `primary`)
- `headerBackground`: `#142B52` — navy del header de marca (`BrandHeader`), **distinto**
  de `primary`; no lo reemplaces por `primary` ni por un gradiente
- `success`: `#146C3C` · `warning`: `#92610C` · `error`: `#A3241A`
- `info`: `#4C7EE0` — azul informativo, más claro/desaturado que `primary`;
  úsalo para iconografía/estados neutros-informativos, reserva `primary` para CTAs
- `sidebarBackground`: `#1B1F27` · `sidebarSurfaceAlt`: `#262B35` (fila
  seleccionada) · `sidebarText`: `#E7E9ED` · `sidebarTextMuted`: `#8B93A3` — el
  sidebar admin es oscuro en AMBOS temas (claro/oscuro), es superficie de marca
  fija, no sigue el tema del sistema

Tema oscuro (`AppColors.dark`): mismos roles, ver valores en el archivo — preparado
para un futuro modo oscuro, TODO-SPEC pendiente de validar contra manual de marca.

TODO-SPEC: `primary` es una aproximación visual del logo de INDI — reemplazar por
el hex exacto en cuanto se tenga el archivo de marca.

## Tipografía (`AppTypography`, `lib/theme/app_typography.dart`)
- Familias: **IBM Plex Sans** (`ibmPlexSans`) para display/headline — títulos con
  presencia de marca; **Manrope** (`manrope`) para title/body/label — texto general;
  **IBM Plex Mono** (`ibmPlexMono`) para datos monoespaciados (ver `AppTextStyles.monoData`).
- Accede vía `Theme.of(context).textTheme.<estilo>` (ya cableado en `AppTheme`), no
  llames `GoogleFonts.*` directo en un widget.
- Escala (`AppTypography.textTheme`): `displayLarge` 40/700, `displayMedium` 32/700,
  `headlineLarge` 28/700, `headlineMedium` 24/600, `headlineSmall` 20/600,
  `titleLarge` 18/700, `titleMedium` 16/700, `titleSmall` 14/700, `bodyLarge` 16/400,
  `bodyMedium` 14/400, `bodySmall` 12/400, `labelLarge` 14/600, `labelMedium` 13/800,
  `labelSmall` 11/600 (todos en Manrope salvo display/headline en IBM Plex Sans).
- Estilos compuestos reutilizables (`AppTextStyles`, `lib/theme/app_text_styles.dart`):
  `formLabel(color)` (label superior en mayúsculas, 13px w800) y
  `monoData(color)` (dato numérico/folio/placa, IBM Plex Mono 14px w500).

## Espaciado (`AppSpacing`, `lib/theme/app_spacing.dart`)
Escala: `xs=4, sm=8, md=12, tile=14 (padding estándar de tiles de lista —
intencional, no un outlier), lg=16, xl=20, xxl=24, xxxl=32`. No inventar valores
fuera de esta escala salvo justificación explícita en comentario.

## Radios de borde (`AppRadii`, `lib/theme/app_radii.dart`)
- `card = 20` (cards, modales)
- `input = 14`
- `badge = 999` (pill — chips/badges de estado)
- `button = 999` (pill — `ElevatedButton` primario, como en la referencia visual)
- `navButton = 14` (radio moderado, NO píldora — ítems de sidebar y botones de
  diálogo, para no verse raro en filas angostas)

## Bordes (`AppBorders`, `lib/theme/app_borders.dart`)
- `hairline = 1.0` — bordes finos de tiles de lista
- `standard = 1.5` — inputs en reposo/error, borde de `OutlinedButton`
- `focus = 2.0` — input enfocado / error enfocado
- `accent = 3.0` — indicador de selección (ítem activo del sidebar)

## Sombras (`AppShadows`, `lib/theme/app_shadows.dart`, `ThemeExtension`)
Solo 2 niveles — accede vía `context.shadows.card` / `context.shadows.raised`:
- `card` (reposo, cards en listas): blur 18, offset `(0, 6)`, negro alpha 0x22
- `raised` (modales/diálogos flotantes): blur 26, offset `(0, 10)`, negro alpha 0x2E

## Transiciones (`AppMotion`, `lib/theme/app_motion.dart`)
- `fast = 150ms` — reservado para microinteracciones futuras
- `base = 250ms` — transición de página (`_conTransicion` en `app_router.dart`) y
  apertura de diálogos (`mostrarDialogoApp` en `app_dialog.dart`)
- `slow = 400ms` — revelado de barras de progreso (tope semanal, presupuesto)
- `curve = Curves.easeOutCubic` — curva sobria por defecto (página, diálogo, barras)
- `celebratory = Curves.elasticOut` — reservada a un solo momento intencional (el
  resultado de una solicitud aprobada en `RespuestaSolicitudScreen`), no para uso general

## Breakpoints (`AppBreakpoints`, `lib/theme/app_breakpoints.dart`)
`mobile = 0`, `tablet = 700` — confirmado por el usuario (no placeholder): el panel
administrativo usa sidebar en escritorio/tablet (`isTabletOrDesktop`) y bottom nav
en móvil (`isMobile`).

## Botones
- Primario (`ElevatedButton`): fondo `colors.primary`, texto `primaryOn`, radio
  `AppRadii.buttonRadius` (píldora), `elevation: 3` + `shadowColor` negro alpha 0.35
  (no plano — el usuario pidió explícitamente restaurar profundidad/sombra).
- Secundario (`OutlinedButton`): borde `AppBorders.standard`, sin fondo.
- Diálogos: usar `OutlinedButton`/`ElevatedButton` de ancho igual dentro de una
  `Row` con `Expanded` (Cancelar / Acción), radio `navButtonRadius` en vez de píldora.

## Inputs
- Fondo `colors.surfaceAlt`, **sin borde visible en reposo** (`BorderSide.none`) —
  decisión explícita del usuario tras comparar contra la referencia visual (nada de
  trazo duro alrededor del campo).
- Focus: borde `colors.primary` con `AppBorders.focus`.
- Error: borde `colors.error` con `AppBorders.standard` (reposo) / `AppBorders.focus`
  (enfocado con error).
- `prefixIcon` en `colors.textMuted` en todos los campos de formulario (login, CRUD).
- Contraseña: el toggle de mostrar/ocultar va como `suffixIcon` (ícono de ojo)
  DENTRO del campo — nunca como botón de texto externo ("Ver"/"Ocultar").
