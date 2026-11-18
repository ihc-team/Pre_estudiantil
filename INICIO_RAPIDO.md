# Inicio rápido

Comandos para correr UniBudget en desarrollo y producción. Todos se ejecutan desde la raíz del repositorio.

## Requisitos

- Flutter
- Docker con `docker compose`
- Certificados TLS para producción

## 1. Configurar el entorno

```bash
cp .env.sample .env
```

Edita `.env`:

```env
API_BASE_URL=http://localhost:3000
DB_PASSWORD=change-me
```

- Para web local usa `http://localhost:3000`.
- Para emulador Android usa `http://10.0.2.2:3000`.
- Para producción, los certificados se configuran con `LETSENCRYPT_DIR`.

No existe un `.env` dentro de `servidor/`; todo se lee desde la raíz.

## 2. Backend y base de datos

```bash
docker compose -f docker-compose.dev.yml up -d --build
docker compose -f docker-compose.dev.yml ps
curl http://localhost:3000/ping
```

Espera `healthy` en `pre_estudiantil_db_dev` y `pre_estudiantil_api_dev`.

```bash
docker compose -f docker-compose.dev.yml logs -f pre_estudiantil-api
docker compose -f docker-compose.dev.yml exec -T pre_estudiantil-api npx prisma db seed
```

Usuario de prueba:

```text
prueba@correo.com
123456
```

## 3. App Flutter Web

```bash
flutter pub get
flutter run -d chrome
```

## 4. App en emulador Android (opcional)

En `.env`:

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

## 5. Pruebas

```bash
flutter test
cd servidor && npm test
cd ..
```

Integración, con backend y dispositivo/emulador activos:

```bash
flutter test integration_test -d <ID_DEL_DISPOSITIVO>
```

## 6. Producción HTTPS

Emitir el certificado con el puerto 80 libre:

```bash
sudo certbot certonly --standalone -d presupuesto.sebaces.fyi
```

Levantar:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Verificar:

```bash
curl -I https://presupuesto.sebaces.fyi
curl https://presupuesto.sebaces.fyi/ping
```

Renovar:

```bash
sudo certbot renew --dry-run
sudo certbot renew
docker compose -f docker-compose.prod.yml restart pre_estudiantil-nginx
```

## 7. Apagar

Desarrollo:

```bash
docker compose -f docker-compose.dev.yml down
docker compose -f docker-compose.dev.yml down -v
```

Producción:

```bash
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml down -v
```

`down -v` borra también los datos de PostgreSQL.

## Problemas comunes

```bash
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs pre_estudiantil-api
flutter devices
flutter doctor
curl http://localhost:3000/ping
```

- Si la API no responde, revisa los logs y que el puerto `3000` esté libre.
- Si el contenedor de base de datos no inicia, revisa `DB_PASSWORD`, `DB_PORT` y que el puerto `55432` esté libre.
- Si cambias dependencias del backend:

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

- Si cambias de dispositivo, actualiza `API_BASE_URL` en `.env` y reinicia la app.
- Si HTTPS no inicia, verifica las rutas de los certificados y `LETSENCRYPT_DIR`.
