# Servidor (API)

API en Node.js + Express con Prisma como ORM y PostgreSQL.

## Instalación

```shell
npm install
```

## Variables de entorno

Copia `.env.example` a `.env` y ajusta `DATABASE_URL` con tus datos de PostgreSQL:

```shell
cp .env.example .env
```

## Base de datos

El esquema está en `prisma/schema.prisma` y la migración inicial en `prisma/migrations/`.

```shell
# Aplicar la migración (producción/despliegue)
npm run prisma:deploy

# Crear/aplicar migraciones en desarrollo
npm run prisma:migrate

# Regenerar el cliente después de cambiar el esquema
npm run prisma:generate
```

## Datos de prueba

```shell
npm run semilla
```

Carga el usuario `prueba@correo.com` con contraseña `123456`.

## Ejecutar

```shell
npm start    # producción
npm run dev  # desarrollo con recarga automática
```

La API queda en `http://localhost:3000`. Comprobación: `GET /ping`.

## Pruebas

```shell
npm test
```
