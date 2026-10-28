# Tarea 1 - Manejo de acceso

**Producto elegido:** Presupuesto Estudiantil (UniBudget)
**Ruta privada:** "Mis movimientos"

## Modalidad

- P1: sin IA
- P2: con IA

**Tipo de aplicación:** app móvil en Flutter, con una API propia en Node.js/Express y base de datos PostgreSQL. La app no se conecta directo a la base de datos: siempre pasa por la API.

## Funcionalidad implementada

| Requisito | Dónde está |
|---|---|
| Registro de cuenta nueva | `PantallaRegistro` → `POST /registro` |
| Inicio de sesión | `PantallaLogin` → `POST /login` |
| Cierre de sesión | Botón de salida en `PantallaMovimientos` → `POST /logout` |
| Recuperación y cambio de contraseña | `PantallaRecuperar` → `POST /recuperar` y `POST /cambiar-contrasena` |
| Sesión conservada al recargar | Token en `shared_preferences`, validado por `PantallaArranque` |
| Ruta pública | `PantallaInicio` (bienvenida) |
| Ruta privada con redirección al login | `PantallaMovimientos`, protegida con `GET /perfil` |
| Nombre de la persona autenticada | "Hola, {nombre}" en `PantallaMovimientos` |

## Decisiones

1. **Sesión con token guardado en la base de datos.** Al iniciar sesión el servidor genera un token aleatorio, lo guarda en la tabla `sesiones` con fecha de expiración (7 días) y lo devuelve a la app. Así el servidor puede invalidar sesiones (cerrar sesión borra la fila).
2. **Contraseñas con hash.** Se guardan con `bcryptjs`; nunca en texto plano.
3. **Protección de la ruta privada en dos lados.** La app no muestra contenido hasta que el servidor confirma el token, y la API rechaza con `401` cualquier petición privada sin sesión válida.
4. **Recuperación sin correo real.** El servidor genera un código de 6 dígitos (tabla `recuperaciones`, vence en 15 minutos, un solo uso) y lo devuelve a la app para mostrarlo en pantalla, como permite la tarea.
5. **Cambiar la contraseña cierra las demás sesiones** de esa cuenta.
6. **Semilla** (`servidor/semilla.js`): crea el usuario de prueba con contraseña real encriptada. Se puede ejecutar varias veces sin duplicar.
7. **Estructura simple por tipo de archivo**, con nombres en español, para que sea fácil de explicar.

## Archivos principales

**Base de datos**
- `base_datos/esquema.sql`: tablas `usuarios`, `sesiones`, `recuperaciones`

**Servidor (`servidor/`)**
- `servidor.js`: rutas de la API y verificación de sesión (`exigirSesion`)
- `conexion.js`: cliente de Prisma (ORM) para PostgreSQL
- `semilla.js`: datos iniciales
- `.env.example`: variables necesarias

**App (`lib/`)**
- `main.dart`: arranque, tema y rutas
- `configuracion/rutas.dart`: pantallas con nombre
- `configuracion/constantes.dart`: colores y dirección del servidor
- `servicios/servicio_acceso.dart`: comunicación con la API y manejo del token
- `pantallas/pantalla_arranque.dart`: decide a dónde ir según la sesión
- `pantallas/pantalla_inicio.dart`, `pantalla_login.dart`, `pantalla_registro.dart`, `pantalla_recuperar.dart`: acceso
- `pantallas/pantalla_movimientos.dart`: ruta privada
- `widgets/`: botón, campo de texto, mensajes y fondo decorativo reutilizables

## API

| Método | Ruta | Requiere sesión |
|---|---|---|
| GET | `/ping` | No |
| POST | `/registro` | No |
| POST | `/login` | No |
| POST | `/recuperar` | No |
| POST | `/cambiar-contrasena` | No |
| GET | `/perfil` | Sí |
| POST | `/logout` | Sí |

## Cómo comprobar la protección de la ruta privada

1. Iniciar sesión con `prueba@correo.com` / `123456`.
2. En pgAdmin ejecutar `DELETE FROM sesiones;`.
3. Cerrar y volver a abrir la app: vuelve a la bienvenida en vez de mostrar "Mis movimientos".

## Limitaciones conocidas

- El token se guarda en `shared_preferences`, que no está cifrado. Para producción convendría `flutter_secure_storage`.
- La app usa `http` (no `https`) y `usesCleartextTraffic` porque el servidor es local de desarrollo.
- El código de recuperación se muestra en pantalla porque no hay envío de correo.
- No hay límite de intentos de login ni de códigos.
- `10.0.2.2` solo funciona en el emulador; en un celular físico habría que usar la IP de la PC.