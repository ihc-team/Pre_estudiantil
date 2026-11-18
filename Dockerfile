# syntax=docker/dockerfile:1

# ---------- Etapa 1: compilar Flutter Web ----------
FROM ghcr.io/project516/flutter:3.47.8 AS build

WORKDIR /app

# La app web llama a /api; nginx quita el prefijo antes de llegar al backend.
ARG API_BASE_URL=/api

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN printf 'API_BASE_URL=%s\nAPP_NAME=UniBudget\n' "$API_BASE_URL" > .env
RUN flutter build web --release

# ---------- Etapa 2: servir la SPA ----------
FROM nginx:alpine

COPY nginx/web.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
