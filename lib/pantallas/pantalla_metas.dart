import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../modelos/meta_ahorro.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_metas.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/resumen_metas_card.dart';
import 'pantalla_detalle_meta.dart';
import 'pantalla_nueva_meta.dart';

class PantallaMetas extends StatefulWidget {
  const PantallaMetas({super.key});

  @override
  State<PantallaMetas> createState() => _PantallaMetasState();
}

class _PantallaMetasState extends State<PantallaMetas> {
  List<MetaAhorro> _metas = [];
  ResumenMetas? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultado = await ServicioMetas.listar();
      if (!mounted) return;
      setState(() {
        _metas = resultado.metas;
        _resumen = resultado.resumen;
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
    }
  }

  Future<void> _abrirNuevaMeta() async {
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaNuevaMeta()),
    );
    if (creada == true) await _cargar();
  }

  Future<void> _abrirDetalle(MetaAhorro meta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PantallaDetalleMeta(meta: meta)),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Metas de ahorro',
          style: AppTypography.titleLarge,
        ),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevaMeta,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: SafeArea(child: _contenido()),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingModal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _cargar,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppSizes.touchTargetMin,
                    AppSizes.touchTargetMin,
                  ),
                ),
                child: Text(
                  'Reintentar',
                  style: AppTypography.bodyLargeSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final resumen = _resumen;
    if (resumen == null) {
      return Center(
        child: Text(
          'No se pudo cargar el resumen de metas.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        96,
      ),
      children: [
        ResumenMetasCard(resumen: resumen),
        const SizedBox(height: AppSpacing.lg),
        if (_metas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: Text(
              'Aún no tienes metas de ahorro.\nCrea la primera con el botón de abajo.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          )
        else
          for (final meta in _metas) _tarjetaMeta(meta),
      ],
    );
  }

  Widget _tarjetaMeta(MetaAhorro meta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.borderCard,
        child: InkWell(
          borderRadius: AppRadius.borderCard,
          onTap: () => _abrirDetalle(meta),
          child: Container(
            padding: AppSpacing.paddingCard,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderCard,
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta.nombre,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${meta.montoReservadoTexto} de ${meta.montoObjetivoTexto}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: AppRadius.borderSm,
                  child: LinearProgressIndicator(
                    value: meta.progreso.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Falta ${meta.restanteTexto} · ${meta.fechaTexto}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
