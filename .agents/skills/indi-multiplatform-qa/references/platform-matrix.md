# Matriz de plataformas por riesgo

| Cambio | Validación mínima |
|---|---|
| Modelo, provider o lógica Dart pura | Analyzer + tests unitarios |
| Widget/layout | Widget tests + móvil angosto + tablet/escritorio |
| Navegación o roles | Tests de router por sesión/rol + deep link inválido |
| HTTP/autenticación/offline | Tests de repositorio + API real de prueba + pérdida/retorno de red |
| Cámara, galería u OCR | Android e iOS reales/emulados; Web/desktop si la feature se expone allí |
| Secure storage | Cada familia de SO soportada y logout/reinicio |
| Notificaciones | Android/iOS: permisos, canal, tap y reinicio |
| Exportar/compartir/archivos | Web y al menos un destino móvil y desktop afectado |
| Cambio nativo/configuración | Build del destino exacto, no solo `flutter analyze` |

Tamaños visuales de referencia: 360x640, 390x844, 430x932, 768x1024, 1024x768, 1366x768 y 1920x1080. Reduce la matriz cuando el alcance sea estrecho y explica el criterio.

