# nginx de borde - UniBudget

Punto de entrada HTTPS para `https://presupuesto.sebaces.fyi`.

- `80/tcp` redirige a `https://presupuesto.sebaces.fyi`.
- `443/tcp` sirve la SPA y la API.
- `/` -> `pre_estudiantil-web:80`
- `/api/` -> `pre_estudiantil-api:3000` (quitando el prefijo `/api/`)
- `/ping` -> `pre_estudiantil-api:3000/ping`

## Archivos

- `Dockerfile`: imagen `nginx:stable-alpine` con `default.conf`.
- `default.conf`: TLS y proxy de borde.
- `web.conf`: configuración interna del contenedor que sirve la SPA.
- `HTTPS.md`: emisión y renovación de certificados.

## Requisito de certificados

Los certificados se montan desde el host en `/etc/letsencrypt`:

```text
/etc/letsencrypt/live/presupuesto.sebaces.fyi/fullchain.pem
/etc/letsencrypt/live/presupuesto.sebaces.fyi/privkey.pem
```

Si están en otra ruta, define `LETSENCRYPT_DIR` en `.env`.

## Uso

No se levanta por separado. Lo orquesta el compose de la raíz:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

La app queda en `https://presupuesto.sebaces.fyi`.
