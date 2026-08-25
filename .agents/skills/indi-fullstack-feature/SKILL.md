---
name: indi-fullstack-feature
description: Implementa features verticales de INDI Combustible que cruzan Flutter, API Express y PostgreSQL, manteniendo contratos, roles, offline, migraciones y pruebas sincronizados. Úsala cuando el cambio afecte frontend/ y backend/ o altere un contrato compartido.
---

# Feature fullstack de INDI Combustible

Entrega un flujo completo y compatible, no dos cambios independientes. Lee [references/contract-checklist.md](references/contract-checklist.md) antes de modificar un contrato o una escritura.

## Estrategia

1. Traza la rebanada completa: ruta Flutter, pantalla, provider, interfaz/adaptador HTTP, endpoint, esquema Zod, servicio, tablas/migraciones y auditoría.
2. Define el contrato antes de editar. Especifica nombres y opcionalidad, formatos de fecha/número, multipart si aplica, códigos de estado, errores, permisos, propiedad, idempotencia y compatibilidad con clientes anteriores.
3. Implementa primero las invariantes duraderas: migración nueva, constraints, transacción y servicio backend. Después adapta endpoint, cliente Flutter, modelos y UI.
4. Mantén autorización simétrica: el router Flutter mejora UX, pero el backend es la autoridad. Prueba todos los roles afectados: `chofer`, `supervisor`, `administrativo` y `superadmin`.
5. En escrituras críticas, diseña el reintento antes del modo offline. No encoles una operación si faltan claves de idempotencia, archivos persistibles o resolución explícita de conflictos.
6. Actualiza pruebas en ambos lados y documentación operativa solo cuando el contrato/comando realmente cambie.

## Puerta de terminado

- El backend compila y pasan sus pruebas relevantes.
- Flutter analiza y pasan pruebas de contrato/provider/widget relevantes.
- Una migración se probó en base de prueba y puede ejecutarse nuevamente sin alterar datos.
- Los estados loading, empty, error, sesión expirada, sin conexión y conflicto tienen un comportamiento visible.
- La feature funciona en los tamaños/plataformas afectados o las validaciones no ejecutadas se declaran con precisión.
- No quedan consumidores del contrato anterior sin adaptar ni secretos/URLs productivas hardcodeadas.

