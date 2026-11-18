# HTTPS - presupuesto.sebaces.fyi

El despliegue usa HTTPS en `443` y redirige `80` a HTTPS.

## 1. Emitir el certificado

Con el puerto 80 libre en el servidor:

```bash
sudo certbot certonly --standalone -d presupuesto.sebaces.fyi
```

Los archivos quedan en:

```text
/etc/letsencrypt/live/presupuesto.sebaces.fyi/fullchain.pem
/etc/letsencrypt/live/presupuesto.sebaces.fyi/privkey.pem
```

## 2. Levantar el despliegue

Desde la raíz del repositorio:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

El compose monta `/etc/letsencrypt` dentro de nginx como solo lectura.

Si los certificados están en otra ruta del host:

```env
LETSENCRYPT_DIR=/ruta/a/letsencrypt
```

## 3. Verificar

```bash
curl -I https://presupuesto.sebaces.fyi
curl https://presupuesto.sebaces.fyi/ping
```

## 4. Renovar

```bash
sudo certbot renew --dry-run
sudo certbot renew
docker compose -f docker-compose.prod.yml restart pre_estudiantil-nginx
```

La renovación real debe programarse con el temporizador de certbot del sistema.
