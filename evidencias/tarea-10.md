# Tarea 10 — "Mis datos y salida honesta"

**Producto:** UniBudget — Presupuesto Estudiantil  
**Integrantes:** Sebastián Céspedes Rodas — Adolfo Mendoza Ribera  
**Fecha de entrega:** Lunes 16/11/2026, 23:59  

---

## 1. Revisión de los 6 Patrones Oscuros en Toda la Aplicación

Se realizó una auditoría rigurosa basada en el checklist de simetría y la pregunta guía: *¿El usuario elegiría esto si entendiera todo lo que pasa?*.

| N° | Patrón Oscuro | Estado | Dónde se identificó | Diagnóstico y Acción Correctiva | Principio de Diseño Aplicado |
|---|---|:---:|---|---|---|
| **1** | **Opciones preseleccionadas** *(Checkboxes marcados)* | **Corregido** | Formulario de movimientos (`pantalla_nuevo_movimiento.dart`) | **Diagnóstico:** Al registrar un gasto, no debe asumirse recurrencia ni categoría por defecto sin intervención del usuario.<br>**Acción:** La categoría inicia en blanco obligando a elección consciente, y la recurrencia inicia apagada (`no`). | **Privacidad por defecto y consentimiento explícito** |
| **2** | **Confirmaciones engañosas** *(Asimetría visual de botones)* | **Corregido** | Diálogo de eliminación de cuenta y diálogo de aviso de límite | **Diagnóstico:** El diálogo de eliminar cuenta destacaba "Eliminar" en rojo chillón frente a un "Cancelar" de texto plano. En el aviso de límite ocurría lo mismo con "Guardar de todas formas".<br>**Acción:** Se igualaron los botones al mismo tamaño, misma altura táctil (48 dp) y pesos visuales balanceados (`OutlinedButton` y `FilledButton` neutrales). | **Simetría de decisión y honestidad de la interfaz (Nielsen #3)** |
| **3** | **Urgencia, culpa o escasez falsas** | **Corregido** | Aviso de superación de límite por categoría (`pantalla_nuevo_movimiento.dart`) | **Diagnóstico:** El texto anterior preguntaba con tono recriminatorio: *"¿Deseas continuar de todas formas?"*.<br>**Acción:** Se cambió a redacción informativa y constructiva: *"Puedes regresar para ajustar el monto o confirmar si decides registrarlo de todas formas."* | **Prevención de errores sin manipulación emocional (Nielsen #5)** |
| **4** | **Datos expuestos sin necesidad** | **Corregido** | Telemetría local (`lib/servicios/analitica.dart`) y perfiles | **Diagnóstico:** Riesgo de registrar montos o conceptos de gastos en eventos de analítica.<br>**Acción:** Estricta exclusión de montos de dinero, conceptos y correos. Solo se registran nombres de eventos y categorías generales. | **Minimización de datos (GDPR / Privacidad)** |
| **5** | **Salir más difícil que entrar** *(Roach Motel)* | **Corregido** | Flujo de cuenta y descarga (`lib/pantallas/pantalla_mis_datos.dart` y `servidor.js`) | **Diagnóstico:** Registrarse toma 1 toque, pero no existía exportación de datos ni pantalla transparente para darse de baja.<br>**Acción:** Se creó la pantalla "Mis datos", botón para descargar todo en JSON con un toque y eliminación directa con borrado en cascada en la BD. | **Control y libertad del usuario (Nielsen #3)** |
| **6** | **Permisos y datos sin explicar** | **Corregido** | Pantalla de Registro (`lib/pantallas/pantalla_registro.dart`) | **Diagnóstico:** Se pedía nombre y correo sin explicar para qué se requerían.<br>**Acción:** Se agregó el aviso informativo: *"Tus datos solo se usarán para gestionar tu presupuesto personal y no se compartirán con terceros."* | **Consentimiento informado y transparencia** |

---

## 2. Antes y Después de las Correcciones Principales

### A. Pantalla "Mis Datos y Cuenta" y Descarga en JSON
* **Antes:** No existía una pantalla para auditar los registros propios. La única forma de salir era un botón "Cerrar sesión" o un submenú oculto.
* **Después:** Pantalla accesible en `/mis-datos` que desglosa la cantidad de movimientos, presupuestos y metas vinculadas, ofreciendo el botón **"Descargar mis datos (JSON)"** que consolida todo el historial en un JSON formateado listo para exportar.

### B. Confirmación Honesta de Eliminación (Simetría de Botones)
* **Antes:**
  * Botón Cancelar: `TextButton` simple de texto verde sin borde ni fondo.
  * Botón Eliminar: `FilledButton` en color rojo llamativo (`Colors.red.shade700`).
  * Asimetría visual que inducía al error o forzaba la atención en lo destructivo.
* **Después:**
  * Ambos botones encapsulados en un `Row` con `Expanded` y altura idéntica de `48 dp` (cumpliendo Fitts).
  * Botón "Cancelar" en `OutlinedButton` con borde visible.
  * Botón "Eliminar" en `FilledButton` sobrio con el color azul del tema.
  * Recuadro informativo recomendando: *"Te recomendamos descargar una copia de tus datos antes de continuar."*

### C. Diálogo de Aviso antes de Superar el Límite
* **Antes:** Botón "Guardar de todas formas" en rojo chillón contra "Cancelar" de texto plano.
* **Después:** Botones simétricos *"Seguir editando"* y *"Confirmar gasto"* con igual tamaño, peso visual y sin juicios de valor.

---

## 3. Justificación de Bloqueos en la Eliminación de Cuenta

* **Verificación de reglas de negocio:** Se auditaron minuciosamente los modelos de datos y endpoints del servidor (`servidor.js` y `schema.prisma`).
* **Conclusión:** En **UniBudget no existe ninguna condición técnica ni financiera que deba bloquear la eliminación de una cuenta**. Los saldos son registros educativos y personales de presupuesto, no existen deudas bancarias activas, contratos legales pendientes ni retenciones judiciales.
* **Principio aplicado:** Crear un bloqueo artificial (como obligar a dejar los saldos en cero antes de borrar la cuenta) constituiría un **patrón oscuro deliberado de retención forzada**. Por tanto, la eliminación borra de inmediato y de forma honesta el usuario y todos sus datos vinculados en cascada (`onDelete: Cascade` en PostgreSQL).

---

## 4. Eventos de Analítica Instrumentados

Siguiendo el principio de privacidad por defecto (cero montos, conceptos ni correos):
* `datos_descargados`: Registra `{ formato: 'json' }` al exportar los datos.
* `cuenta_eliminacion_iniciada`: Se dispara al abrir el diálogo de confirmación para evaluar la intención de salida.
* `cuenta_eliminada`: Se dispara únicamente cuando el servidor confirma el borrado exitoso.

---

## 5. Pruebas y Resultados de Cobertura

1. **Backend (Node.js + Prisma):**
   * Suite en `servidor/tests/cuenta.test.js`:
     * Valida `GET /cuenta/exportar` retornando todos los movimientos, metas y presupuestos en JSON.
     * Valida que tras `DELETE /cuenta`, el usuario y sus datos se eliminan en cascada.
     * Valida que un token previo emitido devuelva `401 Unauthorized` de inmediato tras la eliminación.
   * Resultado: **71 tests pasados exitosamente** (`All tests passed!`).

2. **Frontend (Flutter):**
   * Suite unitaria en `test/mis_datos_test.dart`:
     * Prueba de descarga de datos y trazabilidad en analítica sin datos personales.
     * Prueba de inicio y confirmación de eliminación de cuenta.
     * Prueba de recorrido completo simulando el cierre de sesión forzoso y bloqueo de credenciales tras la eliminación.
   * Suite de Integración / E2E en `integration_test/mis_datos_test.dart` (ejecutado en emulador Android Pixel 4a):
     * **Flujo completo real:** Limpieza inicial de sesión, registro de nuevo usuario, login con botón "Entrar", verificación de "Mis movimientos", acceso al menú de opciones, navegación a "Mis datos", descarga del JSON al portapapeles (disparando evento `datos_descargados`), scroll al botón de salida honesta, confirmación simétrica ingresando contraseña en el diálogo (disparando `cuenta_eliminacion_iniciada` y `cuenta_eliminada`), redirección limpia a la pantalla de login, y comprobación de bloqueo/error al intentar reingresar con la cuenta eliminada.
     * **Robustez en interfaz y ciclo de vida:** Corrección del diálogo de confirmación encapsulado en su propio `StatefulWidget` (`_DialogoConfirmarEliminar`) para garantizar que el `TextEditingController` viva únicamente durante el ciclo de vida del widget y no se destruya prematuramente durante las animaciones de salida de Flutter. Adicionalmente, se incorporó `SingleChildScrollView` dentro del diálogo para prevenir desbordamientos (*RenderFlex overflow*) cuando el teclado virtual del dispositivo móvil se despliega.
   * Resultado: **Todas las pruebas unitarias y de integración pasaron en verde (`All tests passed!`)**.

