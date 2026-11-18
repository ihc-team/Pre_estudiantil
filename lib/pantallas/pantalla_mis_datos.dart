import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../servicios/analitica.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_cuenta.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/app_button.dart';
import '../widgets/mensajes.dart';

class PantallaMisDatos extends StatefulWidget {
  const PantallaMisDatos({super.key});

  @override
  State<PantallaMisDatos> createState() => _PantallaMisDatosState();
}

class _PantallaMisDatosState extends State<PantallaMisDatos> {
  bool _cargando = true;
  bool _descargando = false;
  Map<String, dynamic>? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await ServicioCuenta.exportar();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus datos';
        _cargando = false;
      });
    }
  }

  Future<void> _descargarJson() async {
    if (_datos == null) return;

    setState(() => _descargando = true);
    try {
      final jsonTexto = const JsonEncoder.withIndent('  ').convert(_datos);

      // Copia el JSON completo al portapapeles para mayor compatibilidad
      await Clipboard.setData(ClipboardData(text: jsonTexto));

      // Analitica, se registra la descarga exitosa sin datos personales
      await AnaliticaServicio.track('datos_descargados', {'formato': 'json'});

      if (!mounted) return;
      mostrarMensaje(
        context,
        'Tus datos en formato JSON fueron copiados al portapapeles listos para guardar o compartir.',
      );
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo generar la descarga', esError: true);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = (_datos?['movimientos'] as List?) ?? [];
    final metas = (_datos?['metas'] as List?) ?? [];
    final presupuestos =
        (_datos?['presupuestosCategorias'] as List?) ?? [];
    final usuario = _datos?['usuario'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mis datos y cuenta',
          style: AppTypography.titleLarge,
        ),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: AppSpacing.paddingModal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton.primary(
                        leadingIcon: Icons.refresh,
                        showTrailingIcon: false,
                        size: AppButtonSize.medium,
                        label: 'Reintentar',
                        onPressed: _cargarDatos,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: AppSpacing.paddingModal,
                children: [
                  Text(
                    'Transparencia y control de tus datos',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Aquí puedes revisar toda la informacion registrada en tu cuenta y descargar una copia en formato JSON en cualquier momento.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Tarjeta de perfil
                  Container(
                    padding: AppSpacing.paddingCard,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.borderCard,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario['nombre']?.toString() ?? 'Usuario',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          usuario['correo']?.toString() ?? '',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (usuario['miembroDesde'] != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Miembro desde: ${usuario['miembroDesde']}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Resumen de registros almacenados
                  Text(
                    'Registros vinculados a tu cuenta',
                    style: AppTypography.bodyLargeSemiBold.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _tarjetaResumen(
                    titulo: 'Movimientos financieros',
                    subtitulo: 'Gastos e ingresos registrados',
                    cantidad: movimientos.length,
                    icono: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _tarjetaResumen(
                    titulo: 'Metas de ahorro',
                    subtitulo: 'Objetivos y fondos reservados',
                    cantidad: metas.length,
                    icono: Icons.flag_outlined,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _tarjetaResumen(
                    titulo: 'Presupuestos por categoría',
                    subtitulo: 'Límites mensuales asignados',
                    cantidad: presupuestos.length,
                    icono: Icons.tune_outlined,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Botón para descargar datos
                  SizedBox(
                    height: AppSizes.touchTargetMin,
                    child: AppButton.primary(
                      leadingIcon: _descargando ? null : Icons.download_rounded,
                      showTrailingIcon: false,
                      size: AppButtonSize.medium,
                      isLoading: _descargando,
                      label: 'Descargar mis datos (JSON)',
                      onPressed: _descargando ? null : _descargarJson,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // Zona de salida honesta, que es la eliminacion
                  const Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Zona de cierre de cuenta',
                    style: AppTypography.bodyLargeSemiBold.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Si decides marcharte, respetamos tu decisión. Puedes eliminar tu cuenta de forma permanente y llevarte tus datos.',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, 'solicitar_eliminar');
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      'Eliminar mi cuenta y datos',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppSizes.touchTargetMin,
                      ),
                      side: const BorderSide(color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderCard,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tarjetaResumen({
    required String titulo,
    required String subtitulo,
    required int cantidad,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderCard,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitulo,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.borderSm,
            ),
            child: Text(
              '$cantidad',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
