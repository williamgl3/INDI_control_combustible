---
name: indi-api-backend
description: Desarrolla y modifica la API de INDI Combustible con Express, TypeScript, PostgreSQL, Zod, JWT, migraciones y Vitest. Úsala para endpoints, servicios, autenticación, datos o pruebas dentro de backend/; no aplica a UI Flutter aislada.
---

# Backend de INDI Combustible

Trabaja sobre `backend/` siguiendo el flujo `route -> service -> PostgreSQL`. Las rutas validan y traducen HTTP; los servicios contienen reglas, autorización por recurso y transacciones; la base de datos garantiza integridad y concurrencia.

## Invariantes

- Mantén TypeScript estricto y maneja índices/propiedades opcionales según `tsconfig.json`.
- Valida entradas, parámetros y query strings con Zod. Usa `asyncHandler` y deja la respuesta de errores a `errorHandler`; no expongas detalles internos.
- Aplica `requireAuth` y roles/capacidades en la frontera, pero valida también propiedad y estado del recurso en el servicio.
- Usa consultas parametrizadas. Para cambios con varias escrituras o inventario, usa una transacción, bloqueos/constraints apropiados e idempotencia cuando haya reintentos.
- No edites migraciones ya integradas. Crea el siguiente archivo numerado en `src/db/migrations/`; `schema.sql` es histórico y no reemplaza al runner.
- No revivas `POST /suministros`: es legado y responde `410 Gone`. Los flujos actuales usan partidas, recorridos, despachos y movimientos de inventario.
- Mantén uploads privados o autorizados cuando se toque evidencia; no amplíes la exposición de `/uploads`.
- Nunca registres secretos, tokens, contraseñas ni contenido sensible. Conserva Pino y el logger HTTP central.

## Flujo de implementación

1. Revisa la ruta, servicio, tipos, migraciones y pruebas del dominio vecino.
2. Define primero el contrato HTTP: entrada, respuesta, errores, permisos e idempotencia. Conserva compatibilidad del cliente Flutter o coordina el cambio como feature fullstack.
3. Implementa reglas en el servicio y restricciones duraderas en PostgreSQL. Diferencia claramente `400`, `401`, `403`, `404`, `409`, `410` y errores internos.
4. Prueba el camino feliz y los límites: validación, usuario inactivo/rol, propiedad, estado inválido, duplicados/reintentos y concurrencia cuando aplique.
5. Si agregas una ruta, móntala en `src/index.ts` y comprueba que el middleware de errores permanezca al final.

## Verificación

Desde `backend/`:

```text
npm run build
npm test
```

Si hay migración, prueba `npm run migrate` solo contra una base explícitamente destinada a desarrollo/pruebas y verifica una segunda ejecución idempotente. No ejecutes `seed`, migraciones ni pruebas destructivas contra una base no identificada.

