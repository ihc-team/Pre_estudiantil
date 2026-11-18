# UniBudget - Presupuesto Estudiantil

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

## Pruebas

```bash
flutter test
cd servidor && npm test
```

Pruebas de integración, con backend y dispositivo/emulador activos:

```bash
flutter test integration_test -d <ID_DEL_DISPOSITIVO>
```

## Usuario de prueba

| Correo | Contraseña |
|---|---|
| prueba@correo.com | 123456 |

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
