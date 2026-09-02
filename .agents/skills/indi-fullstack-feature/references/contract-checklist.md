# Checklist de contrato fullstack

Usa esta lista solo cuando se cree o cambie un endpoint o una escritura.

## Entrada

- Método y ruta; path/query/body o multipart.
- Campos requeridos, opcionales y nullable diferenciados.
- Unidades y precisión de litros, dinero, kilómetros y horómetro.
- Fechas con zona horaria explícita; UUID/folio e idempotency key.
- Límites de archivos, MIME y magic bytes.

## Autorización e integridad

- Roles permitidos, propiedad del recurso y transiciones de estado.
- Transacción, locks y constraints que sobreviven concurrencia.
- Resultado de duplicar/reintentar la misma solicitud.
- Registro de auditoría sin datos sensibles.

## Salida y errores

- JSON estable y mapeo exacto al modelo Dart.
- `400` entrada inválida, `401` sesión ausente/inválida, `403` permiso/propiedad, `404` inexistente, `409` conflicto, `410` recurso legado retirado.
- Compatibilidad hacia atrás o migración coordinada de todos los consumidores.

## Pruebas mínimas

- Backend: éxito, validación, rol/propiedad, estado inválido y duplicado.
- Flutter: parsing, request generado, error visible y estado exitoso.
- Integración con PostgreSQL cuando constraints, locks o transacciones sean parte de la corrección.

