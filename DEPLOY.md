# Despliegue en servidor propio (VPS)

Levanta el proyecto completo (Postgres + backend + frontend web) con Docker
Compose desde un solo repo clonado.

## Requisitos del servidor

- Docker + Docker Compose plugin (`docker compose version`).
- Puertos libres `80` (frontend) y `3000` (backend) — o ajusta los mapeos en
  `docker-compose.yml` si ya los usa otra cosa.

## Pasos

```bash
git clone https://github.com/williamgl3/INDI_control_combustible.git
cd INDI_control_combustible

# Variables del backend/BD (credenciales de Postgres, JWT_SECRET, CORS_ORIGIN...)
cp backend/.env.example backend/.env
# edita backend/.env: como mínimo cambia JWT_SECRET, POSTGRES_PASSWORD,
# y pon CORS_ORIGIN con el origin real del frontend (ej. http://TU_IP o
# https://tu-dominio.com) — en NODE_ENV=production el backend no arranca
# sin CORS_ORIGIN definido.

# Variable del frontend (URL pública donde quedará el backend) + las
# credenciales de Postgres repetidas (docker-compose.yml de la raíz solo
# lee el .env de este mismo directorio para interpolar sus variables)
cp .env.example .env
# edita .env: PUBLIC_API_BASE_URL=http://TU_IP:3000 (o tu dominio con HTTPS)
# y que POSTGRES_USER/PASSWORD/DB coincidan exactamente con backend/.env

docker compose build
docker compose up -d
```

Primera vez (crear el esquema y poblar datos base):

```bash
docker compose exec backend npm run migrate
docker compose exec backend npm run seed              # usuarios de prueba chofer1/admin1
# y/o el catálogo real de flotilla:
docker compose exec backend npm run importar:vehiculos -- data/catalogo_vehiculos_gami.csv
docker compose exec backend npm run importar:vehiculos -- data/catalogo_maquinaria_gami.csv
```

## Verificar que quedó arriba

```bash
curl http://localhost:3000/health   # -> {"status":"ok","db":"ok"}
```

Abre `http://TU_IP` (o tu dominio) en el navegador — debe cargar el login de
la app y poder autenticarse contra el backend.

## Notas

- Los volúmenes `indi_pgdata` (datos de Postgres) e `indi_uploads` (fotos
  subidas) son nombrados — persisten entre `docker compose down`/`up`. Solo
  se borran con `docker compose down -v` (evítalo salvo que sea intencional).
- Este `docker-compose.yml` de la raíz no lleva HTTPS — para dominio propio
  con TLS, poner por delante un proxy externo (Caddy/Traefik/nginx del host)
  que termine HTTPS y reenvíe a los puertos `80`/`3000` de este compose, o
  adaptar el compose para que Caddy/Traefik los administre directamente.
- `backend/docker-compose.yml` sigue existiendo aparte para desarrollo local
  (solo Postgres + backend, sin frontend) — no se modificó.
