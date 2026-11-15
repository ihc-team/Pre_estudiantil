import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/fondo_decorativo.dart';

/*
Pantalla publica de bienvenida migrada al sistema de tokens (Clase 23)

Cumple con:
- Cero valores Color(0x...) ni Colors.xxx (usa AppColors)
- Cero estilos de texto o fuentes sueltas (usa AppTypography)
- Cero paddings o espacios con numeros magicos (usa AppSpacing)
- Area tactil minima >= 48dp en botones de enlace (AppSizes.touchTargetMin)
*/
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Capa 1: curvas decorativas
          const Positioned.fill(child: FondoDecorativo()),

          // Capa 2: contenido accesible dirigido por tokens
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  _logo(),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'TU DINERO, TUS METAS',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelTracking,
                  ),
                  const SizedBox(height: AppSpacing.hero - AppSpacing.sm),
                  Text(
                    'Organiza tus ingresos, gastos\ny mantén el control de tu presupuesto\ncomo estudiante universitario.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.hero),
                  BotonPildora(
                    texto: 'Iniciar sesión',
                    icono: Icons.person_outline,
                    alPresionar: () =>
                        Navigator.pushNamed(context, Rutas.login),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BotonPildora(
                    texto: 'Registrarse',
                    icono: Icons.person_add_alt_outlined,
                    esRelleno: false,
                    alPresionar: () =>
                        Navigator.pushNamed(context, Rutas.registro),
                  ),
                  const Spacer(flex: 2),
                  _enlaceOlvidaste(context),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logo: "Uni" en azul oscuro (textPrimary) y "Budget" en verde (primary)
  Widget _logo() {
    return const Text.rich(
      TextSpan(
        style: AppTypography.displayHero,
        children: [
          TextSpan(
            text: 'Uni',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'Budget',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _enlaceOlvidaste(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppSizes.touchTargetMin),
      ),
      onPressed: () => Navigator.pushNamed(context, Rutas.recuperar),
      icon: const Icon(Icons.lock_outline, color: AppColors.primary),
      label: Text(
        '¿Olvidaste tu contraseña?',
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
