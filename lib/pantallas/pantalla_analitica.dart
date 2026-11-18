import 'package:flutter/material.dart';

import '../configuracion/tema/app_tokens.dart';
import '../servicios/analitica.dart';

class PantallaAnalitica extends StatefulWidget {
  const PantallaAnalitica({super.key});

  @override
  State<PantallaAnalitica> createState() => _PantallaAnaliticaState();
}

class _PantallaAnaliticaState extends State<PantallaAnalitica> {
  bool _cargando = true;
  Map<String, dynamic> _datos = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final datos = await AnaliticaServicio.obtenerResumen();
    if (!mounted) return;
    setState(() {
      _datos = datos;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mov = _datos['movimientos'] as Map<String, dynamic>? ?? {};
    final metas = _datos['metas'] as Map<String, dynamic>? ?? {};
    final limites = _datos['limites'] as Map<String, dynamic>? ?? {};
    final aviso = _datos['avisoLimite'] as Map<String, dynamic>? ?? {};
    final errores = _datos['erroresFormulario'] as Map<String, dynamic>? ?? {};
    final busquedasSinRes = _datos['busquedasSinResultado'] as int? ?? 0;
    final ultimos = _datos['ultimos'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analítica de interacción'),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                children: [
                  Text(
                    'Embudos de los flujos principales',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Monitoreo de conversion y caida por flujo (inicio -> exito)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 1. Embudo Movimientos
                  _tarjetaEmbudo(
                    titulo: '1. Registrar movimiento',
                    pasoInicio: 'Iniciados: ${mov['iniciados'] ?? 0}',
                    pasoExito: 'Guardados: ${mov['guardados'] ?? 0}',
                    tasaConversion: '${mov['conversion'] ?? 0.0} %',
                    tasaCaida: '${mov['caida'] ?? 0.0} %',
                    icono: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Embudo metas
                  _tarjetaEmbudo(
                    titulo: '2. Crear Meta de Ahorro',
                    pasoInicio: 'Iniciadas: ${metas['iniciadas'] ?? 0}',
                    pasoExito: 'Guardadas: ${metas['guardadas'] ?? 0}',
                    tasaConversion: '${metas['conversion'] ?? 0.0} %',
                    tasaCaida: '${metas['caida'] ?? 0.0} %',
                    detalleExtra:
                        'Operaciones de fondos: ${metas['fondosOperados'] ?? 0}',
                    icono: Icons.flag_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Embudo limites
                  _tarjetaEmbudo(
                    titulo: '3. Fijar Presupuesto / Limite',
                    pasoInicio: 'Aperturas: ${limites['iniciados'] ?? 0}',
                    pasoExito: 'Guardados: ${limites['guardados'] ?? 0}',
                    tasaConversion: '${limites['conversion'] ?? 0.0} %',
                    tasaCaida: '${limites['caida'] ?? 0.0} %',
                    icono: Icons.savings_outlined,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 4 Efectividad del aviso de limite (Parte B)
                  Text(
                    'Efectividad del aviso de limite (Parte B)',
                    style: AppTypography.bodyLargeSemiBold.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _tarjetaAviso(aviso),
                  const SizedBox(height: AppSpacing.xl),

                  // 5 Puntos de friccion
                  Text(
                    'Puntos de fricción y busquedas en blanco',
                    style: AppTypography.bodyLargeSemiBold.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _tarjetaFriccion(errores, busquedasSinRes),
                  const SizedBox(height: AppSpacing.xxl),

                  // 6 Ultimos Eventos
                  Text(
                    'Ultimos eventos registrados',
                    style: AppTypography.bodyLargeSemiBold.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (ultimos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(
                        'Aun no hay eventos registrados.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final ev in ultimos) _filaEvento(ev),
                ],
              ),
      ),
    );
  }

  Widget _tarjetaEmbudo({
    required String titulo,
    required String pasoInicio,
    required String pasoExito,
    required String tasaConversion,
    required String tasaCaida,
    String? detalleExtra,
    required IconData icono,
  }) {
    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  titulo,
                  style: AppTypography.bodyLargeSemiBold.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pasoInicio,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                pasoExito,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Caida: $tasaCaida',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusNormalContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Exito: $tasaConversion',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (detalleExtra != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detalleExtra,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaAviso(Map<String, dynamic> aviso) {
    final mostrados = aviso['mostrados'] ?? 0;
    final cancelados = aviso['cancelados'] ?? 0;
    final confirmados = aviso['confirmados'] ?? 0;
    final disuasion = aviso['tasaDisuasion'] ?? 0.0;

    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avisos mostrados: $mostrados',
                style: AppTypography.bodyLargeSemiBold.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• Cancelados (evito gasto): $cancelados\n• Confirmados (asumio exceso): $confirmados',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Disuasion: $disuasion %',
            style: AppTypography.bodyLargeSemiBold.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaFriccion(Map<String, dynamic> errores, int busquedasSinRes) {
    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Búsquedas sin resultados: $busquedasSinRes',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Errores que frenaron el formulario:',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (errores.isEmpty)
            Text(
              'Sin errores registrados',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (final entry in errores.entries)
              Text(
                '• ${_motivoLegible(entry.key)}: ${entry.value}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }

  String _motivoLegible(String motivo) {
    return switch (motivo) {
      'concepto_vacio' => 'Concepto vacío',
      'monto_vacio' => 'Monto vacío',
      'monto_invalido' => 'Monto inválido',
      'categoria_vacia' => 'Categoría vacía',
      'fecha_vacia' => 'Fecha vacía',
      'validacion_invalida' => 'Validación inválida',
      _ => motivo,
    };
  }

  Widget _filaEvento(dynamic ev) {
    final nombre = ev['evento'] as String? ?? '';
    final props = ev['props'] as Map<String, dynamic>? ?? {};
    final fecha = ev['fecha'] as String? ?? '';
    final esExito = nombre == 'movimiento_guardado';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm + AppSpacing.xs),
        border: Border.all(
          color: AppColors.borderStrong.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            esExito ? Icons.check_circle_outline : Icons.play_circle_outline,
            color: esExito ? AppColors.primary : AppColors.textPrimary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'tipo: ${props['tipo'] ?? 'desconocido'} · $fecha',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
