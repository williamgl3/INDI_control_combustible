# Build: instala TODAS las dependencias (incl. devDependencies, hacen
# falta typescript/ts-node para compilar) y corre `tsc`.
FROM node:22-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Runtime: solo dependencias de producción + el `dist/` ya compilado —
# imagen final sin devDependencies ni código fuente TypeScript.
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
# TypeScript no copia recursos no-TS. El runner compilado de migraciones
# necesita los SQL en la misma ruta relativa que usa en desarrollo.
COPY --from=build /app/src/db/migrations ./dist/db/migrations

# Ver nota de UPLOADS_DIR en .env.example: sin volumen persistente
# montado aquí, lo que se guarde en esta carpeta se pierde en cada
# redeploy — válido para probar, no para producción real con fotos.
RUN mkdir -p uploads && chown -R node:node /app

EXPOSE 3000
USER node
CMD ["node", "dist/index.js"]
