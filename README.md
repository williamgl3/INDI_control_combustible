# INDI Combustible

Sistema de Control y Autorización de Combustible para Vehículos en Obra —
Grupo INDI.

## Estructura del repositorio

- `frontend/` — app Flutter (Android, iOS, Web, Windows, macOS, Linux). Ver
  [`frontend/README.md`](frontend/README.md) para levantarla.
- `backend/` — API REST (Express + TypeScript + PostgreSQL). Ver
  [`backend/README.md`](backend/README.md) para levantarla. **Este repositorio
  la trae en la rama `feature-backend`** — si no la ves en tu checkout,
  cambia de rama (`git checkout feature-backend`) o pídela para fusionarla.

## Arrancar todo en desarrollo

1. Levanta el backend primero (`backend/README.md`) — Postgres vía Docker,
   `npm run migrate`, `npm run seed`, `npm run dev`.
2. Ajusta `frontend/lib/config/api_config.dart` a `http://localhost:3000` si
   vas a correr el backend local en vez del de producción.
3. Levanta el frontend (`frontend/README.md`).

## CI

Cada carpeta tiene su propio workflow de GitHub Actions
(`.github/workflows/frontend-ci.yml` y `.github/workflows/backend-ci.yml`),
disparados solo cuando cambian archivos dentro de esa carpeta.

## Usuarios de prueba (sembrados por `backend/src/db/seed.ts`)

| Usuario | Contraseña | Rol |
|---|---|---|
| `chofer1` | `chofer123` | chofer |
| `admin1` | `admin1234` | administrativo |
