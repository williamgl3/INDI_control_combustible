# Build reproducible: usa el archivo oficial y checksum publicado para la misma
# versión validada por CI/local. Evita que una etiqueta móvil `stable` cambie el
# Dart SDK sin que cambie este repositorio.
FROM ghcr.io/cirruslabs/flutter@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build
ARG FLUTTER_VERSION=3.44.4
ARG FLUTTER_ARCHIVE_SHA256=c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466
RUN curl --fail --location --retry 3 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output /tmp/flutter.tar.xz \
    && echo "${FLUTTER_ARCHIVE_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --strict \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
WORKDIR /app

# API_BASE_URL se recibe en build time (ver docker-compose.yml de la raíz,
# variable PUBLIC_API_BASE_URL) — mismo mecanismo que ya usa el flujo de
# desarrollo local (`--dart-define=API_BASE_URL=...`), ver
# lib/config/api_config.dart.
ARG API_BASE_URL
ENV API_BASE_URL=${API_BASE_URL}

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Runtime: solo el build estático servido por nginx — sin el SDK de
# Flutter ni el código fuente en la imagen final.
FROM nginx:alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
