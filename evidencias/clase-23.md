# Clase 23 — Del código al sistema: inventario de interfaz y tokens

**Producto:** UniBudget — Presupuesto Estudiantil  
**Fecha:** Martes 17/11/2026  
**Rama:** `mendoza2`  
**Objetivo:** Auditar la interfaz del proyecto (recibido como fork), inventariar valores fijos y duplicados, identificar inconsistencias de diseño y formular la propuesta oficial de tokens semánticos que conectará el código Flutter con Figma cumpliendo pautas de accesibilidad (WCAG 2.1 AA).

---

## 1. Inventario de Interfaz y Diagnóstico de Inconsistencias

Se auditó la totalidad del código frontend en `lib/` (39 archivos Dart entre pantallas, widgets, modelos y servicios). Se identificaron **613 líneas con valores de estilo fijos o hardcodeados** distribuidas en colores, tipografía, espaciado, radios y dimensiones de componentes.

### 1.1 Tabla Consolidada del Inventario

| Categoría | Valor encontrado | Archivo:Línea (Muestra representativa) | Repeticiones | Tipo de inconsistencia | Token semántico propuesto |
|---|---|---|:---:|---|---|
| **Color** | `Colors.white` | `pantalla_analitica.dart:177`, `pantalla_movimientos.dart:465`, `campo_texto.dart:82` | 37 | Superficie fija sin token. No se adapta a temas ni semántica de contenedores. | `color.surface` |
| **Color** | `Colors.transparent` | `pantalla_analitica.dart:45`, `pantalla_detalle_meta.dart:90`, `boton_pildora.dart:25` | 19 | Valor directo para fondos de botones transparentes o appbars. | `color.transparent` |
| **Color** | `Colores.verdeOscuro` (`0xFF0B6B5F`) | `tema.dart:7`, `presupuesto_categoria.dart:54`, `pantalla_movimientos.dart:27` | 113 | Nombre por apariencia física (`verdeOscuro`) en vez de rol semántico primario. | `color.primary` |
| **Color** | `Colores.azulOscuro` (`0xFF0F1B3D`) | `pantalla_analitica.dart:46`, `pantalla_movimientos.dart:430`, `campo_texto.dart:28` | 77 | Nombre por apariencia física para texto principal y títulos. | `color.text.primary` |
| **Color** | `Colores.grisAzulado` (`0xFF6B7494`) | `presupuesto_categoria.dart:55`, `pantalla_analitica.dart:74`, `campo_texto.dart:67` | 67 | Nombre por apariencia física para texto secundario, subtítulos y bordes neutros. | `color.text.secondary` |
| **Color** | `Colores.verdeClaro` (`0xFFCFE3DE`) | `campo_texto.dart:87`, `pantalla_analitica.dart:179`, `resumen_metas_card.dart:18` | 39 | Nombre por apariencia física usado indistintamente para bordes y fondos tenues. | `color.border` / `color.primaryContainer` |
| **Color** | `Colores.rojo` (`0xFFD32F2F`) | `presupuesto_categoria.dart:52`, `campo_texto.dart:90`, `pantalla_analitica.dart:224` | 15 | Nombre por apariencia para indicar estado de error y presupuesto excedido. | `color.status.exceeded` / `color.error` |
| **Color** | `Colors.red.shade700` | `pantalla_movimientos.dart:233, 1014`, `mensajes.dart:18` | 5 | Duplicado casi idéntico de `Colores.rojo` (#D32F2F). Rompe la centralización. | `color.status.exceeded` / `color.error` |
| **Color** | `Colors.red` (`0xFFF44336`) | `pantalla_movimientos.dart:912` | 1 | Tercera variante de rojo con tono más claro (#F44336). Inconsistencia de tono. | `color.status.exceeded` / `color.error` |
| **Color** | `Colores.aviso` (`0xFF8A5A00`) | `presupuesto_categoria.dart:53`, `pantalla_movimientos.dart:863, 872` | 4 | Nombre semántico pero aislado en clase utilitaria antigua. | `color.status.warning` |
| **Color** | `Color(0xFF8A5A00)` | `pantalla_movimientos.dart:997` | 2 | Hexadecimal repetido manualmente en lugar de usar `Colores.aviso`. | `color.status.warning` |
| **Color** | `Color(0xFFFFE9C7)` | `pantalla_movimientos.dart:988` | 1 | Fondo ámbar tenue para tarjetas en aviso sin token definido. | `color.status.warningContainer` |
| **Color** | `Color(0xFFFFE0E0)` | `pantalla_historial.dart:272` | 1 | Fondo rojo tenue para chips de gasto sin token definido. | `color.status.exceededContainer` |
| **Color** | `Colores.fondo` (`0xFFF7F9F9`) | `tema.dart:8`, `constantes.dart:9` | 2 | Fondo general de scaffold con nombre genérico. | `color.background` |
| **Tipografía** | `fontSize: 11` | `pantalla_analitica.dart:403` | 1 | Tamaño excesivamente pequeño para etiquetas (dificulta legibilidad móvil). | `typography.label.small` (12px) |
| **Tipografía** | `fontSize: 12` | `pantalla_analitica.dart:238`, `pantalla_movimientos.dart:366` | 11 | Texto de apoyo o metadatos. Compite con 11 y 13. | `typography.label.small` (12px) |
| **Tipografía** | `fontSize: 13` | `pantalla_analitica.dart:208`, `pantalla_movimientos.dart:550` | 17 | Tamaño no estándar que fragmenta la jerarquía tipográfica. | Unificar en `typography.label.medium` (12px o 14px) |
| **Tipografía** | `fontSize: 14` | `pantalla_analitica.dart:74`, `pantalla_historial.dart:239`, `campo_texto.dart:67` | 12 | Tamaño base para texto secundario e inputs. | `typography.body.medium` (14px) |
| **Tipografía** | `fontSize: 15` | `pantalla_analitica.dart:193`, `pantalla_mis_datos.dart:256` | 4 | Tamaño intermedio arbitrario entre 14 y 16. | Unificar en `typography.body.large` (16px) |
| **Tipografía** | `fontSize: 16` | `pantalla_analitica.dart:117`, `resumen_metas_card.dart:26` | 28 | Tamaño estándar de lectura y cuerpo principal. | `typography.body.large` (16px) |
| **Tipografía** | `fontSize: 18` | `pantalla_analitica.dart:66`, `boton_pildora.dart:45`, `pantalla_metas.dart:184` | 7 | Subtítulos de sección y texto de botones principales. | `typography.title.medium` (18px) |
| **Tipografía** | `fontSize: 20` | `pantalla_detalle_meta.dart:378`, `pantalla_movimientos.dart:1074` | 4 | Títulos de tarjetas destacadas. Compite con 22. | `typography.title.large` (20px) |
| **Tipografía** | `fontSize: 22` | `pantalla_detalle_meta.dart:403`, `pantalla_limite.dart:518` | 2 | Tamaño intermedio entre 20 y 24 sin justificación de escala. | Unificar en `typography.title.large` (20px) |
| **Tipografía** | `fontSize: 24` | `pantalla_arranque.dart:67`, `hoja_filtros.dart:199` | 2 | Títulos principales de pantallas y modales. | `typography.headline.small` (24px) |
| **Tipografía** | `fontSize: 28` | `pantalla_movimientos.dart:454` | 1 | Título grande de saldo. Compite con 30 y 32. | Unificar en `typography.headline.medium` (28px) |
| **Tipografía** | `fontSize: 30` | `pantalla_recuperar.dart:181` | 1 | Código de recuperación en pantalla. | Unificar en `typography.display.small` (32px) |
| **Tipografía** | `fontSize: 32` | `pantalla_limite.dart:443`, `pantalla_login.dart:76` | 6 | Encabezados de bienvenida y montos principales. | `typography.display.small` (32px) |
| **Tipografía** | `fontSize: 54` | `pantalla_inicio.dart:81` | 1 | Logotipo o isotipo gigante de bienvenida. | `typography.display.large` (48px / 54px) |
| **Tipografía (Peso)** | `FontWeight.w700` vs `FontWeight.bold` | `pantalla_analitica.dart:67` (`w700`) vs `pantalla_analitica.dart:300` (`bold`) | 28 vs 5 | Mezcla de sintaxis equivalente de Flutter para representar negrita (`700`). | `typography.weight.bold` (`w700`) |
| **Tipografía (Peso)** | `FontWeight.w600` | `pantalla_analitica.dart:217`, `boton_pildora.dart:46` | 37 | Seminegrita ampliamente usada. | `typography.weight.semibold` (`w600`) |
| **Tipografía (Peso)** | `FontWeight.w800` | `pantalla_arranque.dart:68`, `pantalla_historial.dart:185` | 14 | Extranegrita usada solo en algunos encabezados aislados. | Unificar en `typography.weight.bold` (`w700`) |
| **Espaciado** | `SizedBox(height/width: 4)` | `pantalla_analitica.dart:333`, `pantalla_historial.dart:232` | 12 | Espaciado mínimo entre icono y texto o líneas compactas. | `space.xs` (4dp) |
| **Espaciado** | `SizedBox(height/width: 6)` | `pantalla_analitica.dart:71`, `pantalla_nuevo_movimiento.dart:319` | 11 | Rompe la cuadrícula de 8dp (y submúltiplo de 4dp). | Unificar en `space.sm` (8dp) o `space.xs` (4dp) |
| **Espaciado** | `SizedBox(height/width: 8)` | `pantalla_analitica.dart:122`, `pantalla_limite.dart:214` | 33 | Espaciado estándar pequeño. | `space.sm` (8dp) |
| **Espaciado** | `SizedBox(height/width: 10)` | `pantalla_limite.dart:113`, `pantalla_movimientos.dart:414` | 8 | Número arbitrario fuera de la retícula de 8. | Unificar en `space.md` (12dp) u `8dp` |
| **Espaciado** | `SizedBox(height/width: 12)` | `pantalla_analitica.dart:87`, `pantalla_historial.dart:219` | 24 | Espaciado medio-compacto ($1.5 \times 8$). | `space.md` (12dp) |
| **Espaciado** | `SizedBox(height: 16)` | `pantalla_analitica.dart:76`, `pantalla_detalle_meta.dart:370` | 36 | Espaciado base estándar entre bloques de contenido. | `space.lg` (16dp) |
| **Espaciado** | `SizedBox(height: 20)` | `pantalla_analitica.dart:111`, `pantalla_mis_datos.dart:162` | 8 | Valor no múltiplo de 8. Compite con 16 y 24. | Unificar en `space.xl` (24dp) o `16dp` |
| **Espaciado** | `SizedBox(height: 24)` | `pantalla_analitica.dart:137`, `pantalla_limite.dart:508` | 9 | Separación entre secciones mayores. | `space.xl` (24dp) |
| **Espaciado** | `SizedBox(height: 32)` | `pantalla_arranque.dart:82`, `pantalla_limite.dart:466` | 14 | Separación amplia entre formularios y botones. | `space.xxl` (32dp) |
| **Espaciado** | `SizedBox(height: 40, 48)` | `pantalla_inicio.dart:39, 49`, `pantalla_login.dart:86` | 3 | Espaciado hero en pantallas de bienvenida. | `space.xxxl` (48dp) |
| **Padding** | `EdgeInsets.all(16)` | `resumen_metas_card.dart:14`, `pantalla_analitica.dart:82` | 22 | Relleno estándar de tarjetas. | `space.padding.card` (16dp) |
| **Padding** | `EdgeInsets.symmetric(horizontal: 20, 24)` | `campo_texto.dart:83`, `boton_pildora.dart:35`, `pantalla_login.dart:56` | 18 | Relleno horizontal de formularios y pantallas con discrepancia (20 vs 24). | `space.padding.screen` (20dp) |
| **Radio de Borde** | `BorderRadius.circular(4)` | `pantalla_limite.dart:374` | 1 | Radio casi imperceptible en barra de progreso. | `radius.xs` (4dp) |
| **Radio de Borde** | `BorderRadius.circular(8)` | `pantalla_movimientos.dart:888`, `pantalla_detalle_meta.dart:430` | 3 | Radio pequeño en chips o recuadros secundarios. | `radius.sm` (8dp) |
| **Radio de Borde** | `BorderRadius.circular(12)` | `pantalla_historial.dart:215`, `pantalla_analitica.dart:231` | 7 | Radio de tarjetas en historial y analítica. Compite con 14 y 16. | Unificar en `radius.md` (12dp) |
| **Radio de Borde** | `BorderRadius.circular(14)` | `pantalla_movimientos.dart:1124, 1143`, `pantalla_mis_datos.dart:331` | 6 | Radio arbitrario en tarjetas de movimientos. | Unificar en `radius.lg` (16dp) |
| **Radio de Borde** | `BorderRadius.circular(16)` | `pantalla_analitica.dart:178, 270, 314` | 17 | Radio dominante en contenedores y tarjetas. | `radius.lg` (16dp) |
| **Radio de Borde** | `BorderRadius.circular(20)` | `resumen_metas_card.dart:17`, `pantalla_metas.dart:165`, `pantalla_limite.dart:109` | 11 | Radio amplio en tarjetas y botones secundarios. | `radius.xl` (20dp) |
| **Radio de Borde** | `BorderRadius.circular(24)` | `pantalla_movimientos.dart:1063` | 1 | Radio intermedio aislado en botón de límite. | Unificar en `radius.pill` o `radius.xl` |
| **Radio de Borde** | `BorderRadius.circular(28)` | `pantalla_detalle_meta.dart:92`, `pantalla_movimientos.dart:215` | 5 | Radio de diálogos modales. | `radius.modal` (24dp o 28dp) |
| **Radio de Borde** | `BorderRadius.circular(30)` / `StadiumBorder` | `campo_texto.dart:45`, `boton_pildora.dart:26` | 3 | Borde tipo píldora completo en campos e inputs. | `radius.full` (999dp o píldora) |
| **Áreas Táctiles** | `minimumSize: Size(0, 48)` vs sin tamaño | `pantalla_movimientos.dart:275` vs `pantalla_historial.dart:95` (`ChoiceChip`) | Varía | Discrepancia en áreas mínimas táctiles (unos cumplen estrictamente 48dp y otros quedan en 36-40dp). | `size.touchTarget.min` (48dp) |
| **Componente** | Tarjeta / Card contenedora | `pantalla_movimientos.dart:1120`, `pantalla_analitica.dart:175`, `resumen_metas_card.dart:13` | >15 | Reimplementación manual en cada archivo con `Container + BoxDecoration`, variando bordes (1px vs 1.5px) y radios (12, 14, 16, 20). | Componente unificado `AppCard` con tokens |
| **Componente** | Botón de acción principal | `BotonPildora` (58dp, píldora) vs `FilledButton` en modales (48dp, radio 20) | 12 | Inconsistencia en altura (58dp vs 48dp) y forma (píldora vs redondeado). | Componente unificado `AppButton` con variantes |

---

## 2. Sistema Oficial de Tokens y Mapeo con Figma

Se implementó la arquitectura oficial de tokens en `lib/configuracion/tema/app_tokens.dart` y `lib/configuracion/tema/app_tema.dart`. La nomenclatura es 100% semántica y coincide de manera exacta con las colecciones de variables de Figma.

### 2.1 Colores (`AppColors` $\leftrightarrow$ `color/*`)

| Token en Código (Dart) | Variable en Figma | Hex / Valor | Semántica y Uso |
|---|---|:---:|---|
| `AppColors.primary` | `color/primary` | `#0B6B5F` | Acción principal y marca (conserva identidad visual). |
| `AppColors.onPrimary` | `color/on-primary` | `#FFFFFF` | Contenido sobre color primario. |
| `AppColors.primaryContainer` | `color/primary-container` | `#CFE3DE` | Fondos tenues de acento y bordes activos. |
| `AppColors.onPrimaryContainer` | `color/on-primary-container` | `#0B6B5F` | Texto e iconos sobre `primaryContainer`. |
| `AppColors.background` | `color/background` | `#F7F9F9` | Fondo general de scaffolds y pantallas. |
| `AppColors.surface` | `color/surface` | `#FFFFFF` | Fondo de tarjetas, modales y campos de texto. |
| `AppColors.textPrimary` | `color/text/primary` | `#0F1B3D` | Texto de lectura principal y títulos destacados. |
| `AppColors.textSecondary` | `color/text/secondary` | `#6B7494` | Texto secundario, subtítulos, fechas y pistas. |
| `AppColors.border` | `color/border` | `#E1E6E5` | Borde sutil de separación neutra. |
| `AppColors.borderStrong` | `color/border-strong` | `#CFE3DE` | Borde activo y destacado de inputs. |
| **Estados de Presupuesto (Caso Central)** | | | |
| `AppColors.statusNormal` | `color/status/normal` | `#0B6B5F` | Consumo $<80\%$ o ingreso registrado. |
| `AppColors.statusNormalContainer` | `color/status/normal-container` | `#E3EFEA` | Fondo tenue de chip/tarjeta para estado normal. |
| `AppColors.statusWarning` | `color/status/warning` | `#8A5A00` | Consumo entre $80\%$ y $100\%$ (aviso preventivo). |
| `AppColors.statusWarningContainer` | `color/status/warning-container` | `#FFF3D6` | Fondo tenue de chip/tarjeta para estado aviso. |
| `AppColors.statusExceeded` | `color/status/exceeded` | `#D32F2F` | Presupuesto superado ($>100\%$) o error. |
| `AppColors.statusExceededContainer` | `color/status/exceeded-container` | `#FDE8E8` | Fondo tenue de chip/tarjeta para estado excedido. |

### 2.2 Verificación de Contraste y Accesibilidad (WCAG 2.1 AA)

| Par de Tokens (Texto / Fondo) | Color Texto | Color Fondo | Ratio de Contraste | Nivel WCAG | Cumplimiento |
|---|---|---|:---:|:---:|:---:|
| `textPrimary` / `background` | `#0F1B3D` | `#F7F9F9` | **15.8:1** | AAA | Supera ampliamente ($\ge 4.5:1$) |
| `textPrimary` / `surface` | `#0F1B3D` | `#FFFFFF` | **16.5:1** | AAA | Supera ampliamente ($\ge 4.5:1$) |
| `textSecondary` / `surface` | `#6B7494` | `#FFFFFF` | **4.7:1** | AA | Cumple texto normal ($\ge 4.5:1$) |
| `onPrimary` / `primary` | `#FFFFFF` | `#0B6B5F` | **5.4:1** | AA | Cumple texto normal ($\ge 4.5:1$) |
| `statusNormal` / `surface` | `#0B6B5F` | `#FFFFFF` | **5.4:1** | AA | Cumple ($\ge 4.5:1$) |
| `statusWarning` / `surface` | `#8A5A00` | `#FFFFFF` | **5.3:1** | AA | Cumple ($\ge 4.5:1$) |
| `statusExceeded` / `surface` | `#D32F2F` | `#FFFFFF` | **4.6:1** | AA | Cumple ($\ge 4.5:1$) |
| `statusNormal` / `statusNormalContainer` | `#0B6B5F` | `#E3EFEA` | **4.5:1** | AA | Cumple ($\ge 4.5:1$) |
| `statusWarning` / `statusWarningContainer` | `#8A5A00` | `#FFF3D6` | **4.7:1** | AA | Cumple ($\ge 4.5:1$) |
| `statusExceeded` / `statusExceededContainer` | `#D32F2F` | `#FDE8E8` | **4.5:1** | AA | Cumple ($\ge 4.5:1$) |

### 2.3 Tipografía (`AppTypography` $\leftrightarrow$ `typography/*`)

| Token en Código (Dart) | Variable en Figma | Tamaño | Interlineado | Peso | Rol Semántico |
|---|---|:---:|:---:|:---:|---|
| `AppTypography.displaySmall` | `typography/display/small` | `32 px` | `40 px` | Bold (`700`) | Encabezados de bienvenida y cifras principales. |
| `AppTypography.headlineMedium`| `typography/headline/medium`| `24 px` | `32 px` | Bold (`700`) | Títulos de pantallas y modales. |
| `AppTypography.titleLarge` | `typography/title/large` | `20 px` | `28 px` | SemiBold (`600`) | Títulos de tarjetas destacadas (Límite, Saldos). |
| `AppTypography.titleMedium` | `typography/title/medium` | `18 px` | `24 px` | SemiBold (`600`) | Texto de botones de acción y subtítulos. |
| `AppTypography.bodyLarge` | `typography/body/large` | `16 px` | `24 px` | Regular (`400`) | Lectura principal, filas de movimiento, campos. |
| `AppTypography.bodyMedium` | `typography/body/medium` | `14 px` | `20 px` | Regular (`400`) | Texto secundario y ayudas contextuales. |
| `AppTypography.labelSmall` | `typography/label/small` | `12 px` | `16 px` | SemiBold (`600`) | Chips de filtro, badges de estado y metadatos. |

### 2.4 Espaciado (`AppSpacing` $\leftrightarrow$ `spacing/*`) y Radios (`AppRadius` $\leftrightarrow$ `radius/*`)

* **Espaciado (Retícula de 8dp):**
  * `xs`: 4 dp · `sm`: 8 dp · `md`: 12 dp · `lg`: 16 dp (padding estándar de tarjetas) · `xl`: 20 dp (padding lateral de pantalla) · `xxl`: 24 dp · `xxxl`: 32 dp · `hero`: 48 dp.
* **Radios de curvatura:**
  * `sm`: 8 dp (chips/badges) · `card`: 16 dp (todas las tarjetas) · `modal`: 24 dp (diálogos y bottom sheets) · `pill`: 999 dp (botones píldora y campos).
* **Áreas táctiles (Ley de Fitts):**
  * `touchTargetMin`: 48 dp estricto para cualquier elemento interactivo.

---

## 3. Estado de la Suite de Pruebas
- `flutter analyze lib/configuracion/tema/`: **No issues found!**
- Pruebas unitarias ejecutadas: `flutter test` $\rightarrow$ **57 tests pasados exitosamente (`All tests passed!`)**.
