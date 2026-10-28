# UniBudget - Presupuesto Estudiantil

App móvil para que estudiantes organicen sus ingresos y gastos.
Incluye:
- **Tarea 1:** el manejo de acceso (registro, inicio y cierre de sesión, recuperación de contraseña, sesión conservada, una ruta pública y una ruta privada, "Mis movimientos").
- **Tareas 2 y 3:** el ciclo completo de un movimiento (crear, marcar como pagado, editar y eliminar).
- **HU-01:** el límite mensual de gastos.
- **Tarea 4 (clase 16):** historial de actividad, agrupado por día y filtrable (chips Todos · Gastos · Pagos · Límite). Cada acción (gasto, ingreso, pago, límite) guarda un evento en la misma transacción que la acción.

## Tecnologías

- **App:** Flutter (Dart), probada en el emulador de Android Studio (Pixel 6a)
- **API:** Node.js + Express
- **Base de datos:** PostgreSQL

```
App Flutter  →  API (servidor/)  →  PostgreSQL
```

## Requisitos

- Flutter y Dart
- Android Studio con un emulador Android
- Node.js (v18 o superior)
- PostgreSQL

## Cómo iniciar el proyecto

### 1. Base de datos

La API usa **Prisma** como ORM. El esquema vive en `servidor/prisma/schema.prisma` y la única migración (`servidor/prisma/migrations/`) crea todas las tablas, relaciones, índices y restricciones de una vez.

Crea la base (si usas Docker, `docker compose -f servidor/docker-compose.dev.yml up -d` ya la crea):

```sql
CREATE DATABASE presupuesto_estudiantil;
```

### 2. Servidor (API)

```powershell
cd servidor
copy .env.example .env
```

Abre `servidor/.env` y ajusta `DATABASE_URL` (usuario, contraseña, puerto y nombre de la base). Luego:

```powershell
npm install
npm run prisma:deploy
npm run semilla
npm start
```

- `npm run prisma:deploy` aplica la migración. En desarrollo también puedes usar `npm run prisma:migrate`.
- `npm run semilla` carga el usuario de prueba (ver más abajo).
- `npm start` deja la API en `http://localhost:3000`. Déjala corriendo.
- Comprobación: abrir `http://localhost:3000/ping` debe mostrar `{"mensaje":"Servidor funcionando"}`.

### 3. App Flutter

Con el emulador de Android encendido, desde la raíz del proyecto:

```powershell
flutter pub get
flutter run
```

La app se conecta a `http://10.0.2.2:3000` (en el emulador, `10.0.2.2` es el `localhost` de la PC). Esta dirección está en `lib/configuracion/constantes.dart`.

## Usuario de prueba (semilla)

| Correo | Contraseña |
|---|---|
| prueba@correo.com | 123456 |

## Recuperación de contraseña

No se envía correo real. Al pedir el código, la app lo muestra en pantalla (6 dígitos, válido 15 minutos).

## Pruebas unitarias

Desde la raíz del proyecto:

```powershell
flutter test
```

Las pruebas están en `test/`:

- `movimiento_test.dart`: estado inicial, transición `pendiente → pagado`, rechazo de transición inválida y conservación de datos.
- `restriccion_monto_test.dart`: un movimiento pagado no permite modificar su monto.
- `limite_validaciones_test.dart`: el límite mensual se acepta si es mayor a 0 y se rechaza si está vacío, en 0, es negativo o tiene letras.

Las pruebas del servidor (la misma regla del límite) se corren desde `servidor/`:

```powershell
npm test
```

## Límite mensual (HU-01)

- En "Mis movimientos", el ícono de la alcancía abre "Límite del mes".
- El límite tiene que ser un número mayor a 0. Si no lo es, el mensaje "El límite debe ser un número mayor a 0" aparece debajo del campo.
- Se guarda en `usuarios.limite_mensual` y se lee con `GET /limite` y `PUT /limite`, con sesión.

## Historial de actividad (Tarea 4)

- En "Mis movimientos", el botón **"Historial"** (barra superior) abre la pantalla.
- 4 chips mutuamente excluyentes (**Todos · Gastos · Pagos · Límite**) y lista agrupada por día (Hoy / Ayer / "12 de octubre").
- Cada acción guarda su evento en la misma transacción: `POST /movimientos` → `gasto_registrado`/`ingreso_registrado`; `POST /movimientos/:id/pagar` → `movimiento_pagado`; `PUT /limite` → `limite_definido`.
- Consulta: `GET /historial?tipo=<todos|gastos|pagos|limite>`, siempre filtrada por `req.usuario.id`.
- Las 3 decisiones de interacción (Fitts, Hick, carga cognitiva) están en [`docs/decisiones-interaccion.md`](docs/decisiones-interaccion.md).

## Documentación

- [`docs/task-01-access.md`](docs/task-01-access.md): Tarea 1, acceso.
- [`docs/task-02-state-tests.md`](docs/task-02-state-tests.md): Tarea 2, estado y pruebas.
- [`docs/task-03-edit-delete.md`](docs/task-03-edit-delete.md): Tarea 3, editar y eliminar.
- [`docs/historias/HU-01-limite-mensual.md`](docs/historias/HU-01-limite-mensual.md): HU-01, límite mensual.
- [`docs/clase-15-heuristicas.md`](docs/clase-15-heuristicas.md): clase 15, evaluación heurística H1-H10.
- [`docs/clase-16-decisiones-interaccion.md`](docs/clase-16-decisiones-interaccion.md): clase 16, decisiones de interacción (filtros).
- [`docs/decisiones-interaccion.md`](docs/decisiones-interaccion.md): Tarea 4 (clase 16), decisiones aplicadas al Historial.
- [`docs/bitacora.md`](docs/bitacora.md): bitácora del proyecto.
- [`docs/issue-07-buscar-filtrar.md`](docs/issue-07-buscar-filtrar.md): Buscar y filtrar movimientos.