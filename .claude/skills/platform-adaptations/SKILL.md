---
name: platform-adaptations
description: "Usa esta skill al construir o revisar cualquier pantalla que deba funcionar en Android, iOS y Web, para adaptar comportamientos específicos de plataforma (safe areas, tamaños táctiles, atajos de teclado, layout en pantallas anchas)."
---

# Adaptaciones por plataforma

## Móvil (Android / iOS)
- Respeta `SafeArea` en todas las pantallas con contenido cerca de los bordes.
- Área táctil mínima de 44x44px en cualquier elemento interactivo.
- Usa bottom navigation bar como patrón principal de navegación.
- En iOS, respeta el patrón de "back" con swipe desde el borde; no lo bloquees salvo pantallas de formulario con cambios sin guardar (mostrar confirmación).
- Cámara/galería para subir fotos: usar `image_picker`, pedir permisos con mensaje claro antes del prompt del sistema.

## Web / Desktop
- Sustituir bottom navigation por un rail lateral o sidebar cuando el ancho supere 1024px.
- Soportar hover states en botones y cards (no solo estados táctiles).
- Soportar atajos de teclado básicos: `Tab` para navegar formularios, `Enter` para submit.
- Ajustar el ancho máximo de contenido en pantallas grandes (ej. `maxWidth: 480px` para formularios centrados) en vez de estirar todo a lo ancho de la ventana.

## General
- Estado real del proyecto: todo diálogo usa `AppDialogShell`/`mostrarDialogoApp`
  (`lib/widgets/app_dialog.dart`, ver skill `component-library`) — un `Dialog`
  centrado con transición fade+scale de marca, **en todas las plataformas,
  incluida móvil**. Todavía NO hay una variante `showModalBottomSheet` para
  móvil — es una divergencia conocida de esta regla, no una implementación
  pendiente de verificar. Si el usuario pide bottom sheets en móvil, es un
  cambio a proponer explícitamente (afecta los ~8 diálogos existentes), no algo
  para aplicar solo en un diálogo nuevo.
- Las transiciones de PÁGINA (no diálogo) usan un único helper compartido,
  `_conTransicion` en `app_router.dart` (fade + slide con `AppMotion`), igual en
  todas las plataformas — decisión explícita del usuario de consistencia visual
  por encima de convenciones nativas por plataforma (Cupertino en iOS no aplica aquí).
