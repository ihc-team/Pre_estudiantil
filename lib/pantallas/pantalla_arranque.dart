import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../servicios/servicio_acceso.dart';
import '../widgets/app_button.dart';

class PantallaArranque extends StatefulWidget {
  const PantallaArranque({super.key});

  @override
  State<PantallaArranque> createState() => _PantallaArranqueState();
}

class _PantallaArranqueState extends State<PantallaArranque> {
  // Hay sesión guardada pero el servidor no respondió (H9.3)
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    _decidirDestino();
  }

  Future<void> _decidirDestino() async {
    if (_sinConexion) setState(() => _sinConexion = false);
    String? nombre;
    try {
      nombre = await ServicioAcceso.obtenerNombreSesion();
    } on ErrorAcceso {
      // Sin conexión no se sabe si la sesión vale: se avisa en vez de mandar a Inicio
      if (mounted) setState(() => _sinConexion = true);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      nombre != null ? Rutas.movimientos : Rutas.inicio,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sinConexion) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No se pudo conectar con el servidor',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu sesión sigue guardada. Revisa tu conexión e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton.primary(
                label: 'Reintentar',
                leadingIcon: Icons.refresh,
                onPressed: _decidirDestino,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
