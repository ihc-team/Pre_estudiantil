# Servidor (API)

API en Node.js + Express con Prisma como ORM y PostgreSQL.

## Instalación

```shell
npm install
```

## Variables de entorno

Copia `.env.example` a `.env` y ajusta con tus datos de PostgreSQL:

```shell
cp .env.example .env
```

## Base de datos

El esquema está en `prisma/schema.prisma` y la migración inicial en `prisma/migrations/`.

```shell
# Cuestionario para configurar prisma por primera vez
npx prisma init

# Aplicar la migración (producción/despliegue)
npx prisma migrate deploy 

# Crear/aplicar migraciones en desarrollo y generar los tipos en @client
npx prisma migrate dev

# Regenerar los tipos en @client
npx prisma generate 

# Generar las migraciones 
npx prisma migrate dev --name init  

# Para resetear la base de datos y aplicar las migraciones
npx prisma migrate reset
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
