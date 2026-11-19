# UniBudget - Presupuesto Estudiantil

[![Pruebas](https://github.com/ihc-team/Pre_estudiantil/actions/workflows/pruebas.yml/badge.svg?branch=main)](https://github.com/ihc-team/Pre_estudiantil/actions/workflows/pruebas.yml)

Aplicación Flutter para registrar ingresos, gastos, límites y metas de ahorro. La API es Node.js + Express + Prisma y la base de datos es PostgreSQL 16.

```text
Flutter Web  ->  nginx HTTPS  ->  API Node.js  ->  PostgreSQL
```

## Requisitos

- Flutter
- Docker con `docker compose`
- Un dominio con certificados para producción: `presupuesto.sebaces.fyi`

## Configuración: un solo `.env`

Toda la configuración está en `.env`, en la raíz. No hay archivos `.env` dentro de `servidor/`.

```bash
cp .env.sample .env
```

Variables principales:

```env
API_BASE_URL=http://localhost:3000
APP_NAME="UniBudget"

DB_HOST=localhost
DB_PORT=55432
DB_USER=postgres
DB_PASSWORD=change-me
DB_NAME=postgres
SERVER_PORT=3000

DOMAIN=presupuesto.sebaces.fyi
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
LETSENCRYPT_DIR=/etc/letsencrypt
```

Para web local, deja `API_BASE_URL=http://localhost:3000`. El Docker de producción compila la web con `/api` automáticamente.

## Desarrollo

### 1. Backend y base de datos

```bash
docker compose -f docker-compose.dev.yml up -d --build
docker compose -f docker-compose.dev.yml ps
curl http://localhost:3000/ping
```

Logs y semilla:

```bash
docker compose -f docker-compose.dev.yml logs -f pre_estudiantil-api
docker compose -f docker-compose.dev.yml exec -T pre_estudiantil-api npx prisma db seed
```

### 2. App Flutter Web

```bash
flutter pub get
flutter run -d chrome
```

### 3. App en emulador Android (opcional)

Cambia en `.env`:

```env
API_BASE_URL=http://10.0.2.2:3000
```

Luego:

```bash
flutter emulators
flutter emulators --launch <ID_DEL_EMULADOR>
flutter devices
flutter run -d <ID_DEL_DISPOSITIVO>
```

## Producción con HTTPS

### 1. Certificados

Con el puerto 80 libre:

```bash
sudo certbot certonly --standalone -d presupuesto.sebaces.fyi
```

Los certificados deben existir en:

```text
/etc/letsencrypt/live/presupuesto.sebaces.fyi/fullchain.pem
/etc/letsencrypt/live/presupuesto.sebaces.fyi/privkey.pem
```

Si están en otra ruta, ajusta `LETSENCRYPT_DIR` en `.env`.

### 2. Levantar

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Abre `https://presupuesto.sebaces.fyi`. Los puertos públicos son `NGINX_HTTP_PORT` (80) y `NGINX_HTTPS_PORT` (443).

Imágenes publicadas en Docker Hub:

```text
sebastiandevjs/pre_estudiantil-web:latest
sebastiandevjs/pre_estudiantil-api:latest
sebastiandevjs/pre_estudiantil-nginx:latest
```

### 3. Verificar

```bash
curl -I https://presupuesto.sebaces.fyi
curl https://presupuesto.sebaces.fyi/ping
```

### 4. Apagar

```bash
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml down -v
```

`down -v` elimina los datos de PostgreSQL.

## Pruebas y cobertura

```bash
flutter test
flutter test --coverage
cd servidor && npm test
```

El workflow [`pruebas.yml`](.github/workflows/pruebas.yml) corre las **unitarias Flutter** y publica `coverage/lcov.info` como artefacto. La insignia enlaza a la última ejecución.

**Las pruebas E2E Android no se ejecutan en GitHub Actions.** El emulador se queda colgado en el `Terminate Emulator`/teardown y agota el timeout del job, aunque la suite de tests termine correctamente. Por eso se excluyeron del CI; se ejecutan manualmente con backend y emulador activos:

```bash
docker compose -f docker-compose.dev.yml up -d
flutter test integration_test -d <ID_DEL_EMULADOR>
```

Esto mantiene el workflow verde sin afirmar que el CI ejecuta E2E.

Cobertura actual de las unitarias Flutter: **95,05 % (2879/3029 líneas)**, es decir, una cobertura parcial prácticamente completa (≈100 %). Las **152 pruebas unitarias pasan**; lo que resta son ramas defensivas y de error poco frecuentes en pantallas. El porcentaje sale de `flutter test --coverage` y se puede revisar con `coverage/lcov.info`.

### Cobertura de las líneas nuevas (diff-cover)

La cobertura que exige la tarea final se calcula solo sobre las líneas agregadas en el fork, no sobre todo el proyecto. Instala `diff-cover` y genera el reporte desde la raíz:

```bash
python -m pip install diff-cover
flutter test --coverage
diff-cover coverage/lcov.info --compare-branch=origin/main --html-report build/coverage/diff-cover.html
```

Para usarlo como compuerta de 100 %:

```bash
diff-cover coverage/lcov.info --compare-branch=origin/main --fail-under=100
```

El reporte HTML queda en `build/coverage/diff-cover.html`. Ajusta `origin/main` si la rama base del fork es otra.

Pruebas de integración, con backend y dispositivo/emulador activos:

```bash
flutter test integration_test -d <ID_DEL_DISPOSITIVO>
```

## Usuarios de prueba

| Correo | Contraseña | Nombre |
|---|---|---|
| prueba@correo.com | 123456 | Usuario Prueba |
| prueba1@correo.com | 123456 | Ana Torres |
| prueba2@correo.com | 123456 | Luis Rojas |

## Estructura

```text
Dockerfile                 Flutter Web + nginx interno
Dockerfile.prod            API Node.js de producción
docker-compose.dev.yml     Backend y PostgreSQL de desarrollo
docker-compose.prod.yml    Web, API, PostgreSQL y nginx HTTPS
nginx/                     Configuración y Dockerfile del borde HTTPS
servidor/                  API Express + Prisma
lib/                       Código Flutter
web/                       Entrada de Flutter Web
```

## Documentación

- [Inicio rápido](INICIO_RAPIDO.md)
- [Certificados HTTPS](nginx/HTTPS.md)
- [API](servidor/README.md)
