import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../modelos/meta_ahorro.dart';
import '../servicios/analitica.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_metas.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/mensajes.dart';
import '../widgets/resumen_metas_card.dart';

class PantallaDetalleMeta extends StatefulWidget {
  final MetaAhorro meta;

  const PantallaDetalleMeta({super.key, required this.meta});

  @override
  State<PantallaDetalleMeta> createState() => _PantallaDetalleMetaState();
}

class _DatosTransferencia {
  final MetaAhorro destino;
  final double monto;

  const _DatosTransferencia(this.destino, this.monto);
}

class _PantallaDetalleMetaState extends State<PantallaDetalleMeta> {
  late MetaAhorro _meta;
  ResumenMetas? _resumen;
  List<MetaAhorro> _metas = [];
  List<MovimientoMeta> _historial = [];
  bool _cargando = true;
  bool _operando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _meta = widget.meta;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultado = await ServicioMetas.listar();
      final meta = resultado.metas.firstWhere(
        (m) => m.id == widget.meta.id,
        orElse: () => _meta,
      );
      final historial = await ServicioMetas.historial(meta.id);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _metas = resultado.metas;
        _resumen = resultado.resumen;
        _historial = historial;
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

  Future<double?> _pedirMonto({
    required String titulo,
    required String pista,
  }) async {
    final controlador = TextEditingController();
    String? error;

    final resultado = await showDialog<double>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setStateDialogo) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          title: Text(
            titulo,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controlador,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monto (Bs)',
              hintText: pista,
              errorText: error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTargetMin),
              ),
              onPressed: () => Navigator.pop(contexto),
              child: Text(
                'Cancelar',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, AppSizes.touchTargetMin),
              ),
              onPressed: () {
                final monto = double.tryParse(
                  controlador.text.trim().replaceAll(',', '.'),
                );
                if (monto == null || monto <= 0) {
                  setStateDialogo(() => error = 'Escribe un monto mayor a 0');
                  return;
                }
                Navigator.pop(contexto, monto);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return resultado;
  }

  Future<_DatosTransferencia?> _pedirTransferencia(
    List<MetaAhorro> destinos,
  ) async {
    final controlador = TextEditingController();
    MetaAhorro? destino = destinos.first;
    String? error;

    final resultado = await showDialog<_DatosTransferencia>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setStateDialogo) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          title: Text(
            'Transferir fondos',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Meta destino',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MetaAhorro>(
                    isExpanded: true,
                    value: destino,
                    items: destinos
                        .map(
                          (meta) => DropdownMenuItem(
                            value: meta,
                            child: Text(meta.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) =>
                        setStateDialogo(() => destino = valor),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controlador,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monto (Bs)',
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTargetMin),
              ),
              onPressed: () => Navigator.pop(contexto),
              child: Text(
                'Cancelar',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, AppSizes.touchTargetMin),
              ),
              onPressed: () {
                final monto = double.tryParse(
                  controlador.text.trim().replaceAll(',', '.'),
                );
                if (monto == null || monto <= 0) {
                  setStateDialogo(() => error = 'Escribe un monto mayor a 0');
                  return;
                }
                if (destino == null) {
                  setStateDialogo(() => error = 'Elige una meta de destino');
                  return;
                }
                Navigator.pop(contexto, _DatosTransferencia(destino!, monto));
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return resultado;
  }

  Future<void> _operar(
    Future<ResultadoMeta> Function() accion,
    String mensaje,
  ) async {
    setState(() => _operando = true);
    try {
      await accion();
      if (!mounted) return;
      mostrarMensaje(context, mensaje);
      await _cargar();
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  Future<void> _asignar() async {
    final monto = await _pedirMonto(
      titulo: 'Asignar fondos',
      pista: 'Dinero desde el saldo disponible',
    );
    if (monto == null) return;
    await _operar(
      () async {
        final res = await ServicioMetas.asignar(_meta.id, monto);
        AnaliticaServicio.track('fondos_meta_operados', {'operacion': 'asignar'});
        return res;
      },
      'Fondos asignados',
    );
  }

  Future<void> _retirar() async {
    final monto = await _pedirMonto(
      titulo: 'Retirar fondos',
      pista: 'Dinero reservado en esta meta',
    );
    if (monto == null) return;
    await _operar(
      () async {
        final res = await ServicioMetas.retirar(_meta.id, monto);
        AnaliticaServicio.track('fondos_meta_operados', {'operacion': 'retirar'});
        return res;
      },
      'Fondos retirados',
    );
  }

  Future<void> _transferir() async {
    final destinos = _metas.where((m) => m.id != _meta.id).toList();
    if (destinos.isEmpty) {
      mostrarMensaje(
        context,
        'Necesitas al menos otra meta para transferir',
        esError: true,
      );
      return;
    }

    final datos = await _pedirTransferencia(destinos);
    if (datos == null) return;
    await _operar(
      () async {
        final res = await ServicioMetas.transferir(_meta.id, datos.destino.id, datos.monto);
        AnaliticaServicio.track('fondos_meta_operados', {'operacion': 'transferir'});
        return res;
      },
      'Transferencia realizada',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_meta.nombre),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTargetMin),
                ),
                onPressed: _cargar,
                child: Text(
                  'Reintentar',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: [
        if (_resumen != null) ResumenMetasCard(resumen: _resumen!),
        const SizedBox(height: AppSpacing.lg),
        _tarjetaMeta(),
        const SizedBox(height: AppSpacing.lg),
        _acciones(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Historial',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _historialWidget(),
      ],
    );
  }

  Widget _tarjetaMeta() {
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
            _meta.nombre,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Objetivo: ${_meta.montoObjetivoTexto}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Reservado: ${_meta.montoReservadoTexto}',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Falta: ${_meta.restanteTexto}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Fecha objetivo: ${_meta.fechaTexto}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: _meta.progreso.clamp(0, 1).toDouble(),
              minHeight: 10,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acciones() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: _operando ? null : _asignar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(0, AppSizes.touchTargetMin),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Asignar'),
        ),
        OutlinedButton.icon(
          onPressed: _operando ? null : _retirar,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(0, AppSizes.touchTargetMin),
          ),
          icon: const Icon(Icons.remove),
          label: const Text('Retirar'),
        ),
        OutlinedButton.icon(
          onPressed: _operando ? null : _transferir,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(0, AppSizes.touchTargetMin),
          ),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Transferir'),
        ),
      ],
    );
  }

  Widget _historialWidget() {
    if (_historial.isEmpty) {
      return Text(
        'Aún no hay movimientos para esta meta.',
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (final movimiento in _historial) _itemHistorial(movimiento),
      ],
    );
  }

  Widget _itemHistorial(MovimientoMeta movimiento) {
    final esEntrada =
        movimiento.tipo == 'asignacion' ||
        movimiento.tipo == 'transferencia_entrada';
    final color = esEntrada ? AppColors.primary : AppColors.error;
    final signo = esEntrada ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Icon(
            esEntrada ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movimiento.tipoTexto,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (movimiento.metaRelacionada != null)
                  Text(
                    'Meta: ${movimiento.metaRelacionada}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  movimiento.fechaTexto,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$signo${movimiento.montoTexto}',
            style: AppTypography.bodyLargeSemiBold.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
