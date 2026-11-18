import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../servicios/servicio_acceso.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _errorCorreo;
  String? _errorContrasena;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final correo = _correo.text.trim();
    final contrasena = _contrasena.text;

    setState(() {
      _errorCorreo = correo.isEmpty ? mensajeCampoVacio : null;
      _errorContrasena = contrasena.isEmpty ? mensajeCampoVacio : null;
    });
    if (_errorCorreo != null || _errorContrasena != null) return;

    setState(() => _cargando = true);
    try {
      await ServicioAcceso.iniciarSesion(correo, contrasena);
      if (!mounted) return;
      // Entramos a la zona privada y borramos el historial de pantallas
      Navigator.pushNamedAndRemoveUntil(
        context,
        Rutas.movimientos,
        (ruta) => false,
      );
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Iniciar sesión',
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Entra para ver tus movimientos.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              CampoTexto(
                controlador: _correo,
                etiqueta: 'Correo',
                icono: Icons.mail_outline,
                tipoTeclado: TextInputType.emailAddress,
                error: _errorCorreo,
                alCambiar: (_) {
                  if (_errorCorreo != null) setState(() => _errorCorreo = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              CampoTexto(
                controlador: _contrasena,
                etiqueta: 'Contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
                error: _errorContrasena,
                alCambiar: (_) {
                  if (_errorContrasena != null) {
                    setState(() => _errorContrasena = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : BotonPildora(
                        texto: 'Entrar',
                        icono: Icons.person_outline,
                        alPresionar: _iniciarSesion,
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, Rutas.recuperar),
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppSizes.touchTargetMin,
                    AppSizes.touchTargetMin,
                  ),
                ),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppTypography.bodyLargeSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, Rutas.registro),
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppSizes.touchTargetMin,
                    AppSizes.touchTargetMin,
                  ),
                ),
                child: Text(
                  '¿No tienes cuenta? Regístrate',
                  style: AppTypography.bodyLargeSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
