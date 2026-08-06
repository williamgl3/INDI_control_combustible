# Build: compila el frontend Flutter a Web.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# API_BASE_URL se recibe en build time (ver docker-compose.yml de la raíz,
# variable PUBLIC_API_BASE_URL) — mismo mecanismo que ya usa el flujo de
# desarrollo local (`--dart-define=API_BASE_URL=...`), ver
# lib/config/api_config.dart.
ARG API_BASE_URL
ENV API_BASE_URL=${API_BASE_URL}

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Runtime: solo el build estático servido por nginx — sin el SDK de
# Flutter ni el código fuente en la imagen final.
FROM nginx:alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
