import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../modelos/evento.dart';
import '../modelos/limite.dart' show formatearBs;
import '../servicios/servicio_historial.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/app_button.dart';
import '../widgets/mensajes.dart';

// Historial de actividad (Tarea 4): lista agrupada por día, filtrable por chip.
// Migrada al Sistema Oficial de Tokens (AppColors, AppTypography, AppSpacing, AppRadius).
class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  List<GrupoDia> _grupos = [];
  FiltroHistorial _filtro = FiltroHistorial.todos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final grupos = await ServicioHistorial.listar(filtro: _filtro);
      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _cargando = false;
      });
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, _mensajeError(e), esError: true);
    }
  }

  String _mensajeError(Exception e) {
    final texto = e.toString();
    return texto.startsWith('Instance of ')
        ? 'No se pudo cargar el historial'
        : texto;
  }

  Future<void> _cambiarFiltro(FiltroHistorial nuevo) async {
    if (_filtro == nuevo) return;
    setState(() => _filtro = nuevo);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Historial',
          style: AppTypography.titleLarge,
        ),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _barraFiltros(),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  // Hick: 5 chips mutuamente excluyentes organizados en Wrap.
  // Todos están visibles sin necesidad de scroll horizontal.
  Widget _barraFiltros() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final f in FiltroHistorial.values)
          ChoiceChip(
            label: Text(f.etiqueta),
            selected: _filtro == f,
            onSelected: (_) => _cambiarFiltro(f),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.primaryContainer,
            labelStyle: AppTypography.bodyMedium.copyWith(
              color: _filtro == f ? AppColors.onPrimary : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            shape: const StadiumBorder(side: BorderSide.none),
            side: BorderSide.none,
            showCheckmark: false,
          ),
      ],
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_grupos.isEmpty) return _estadoVacio();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      itemCount: _grupos.length,
      itemBuilder: (context, i) => _grupoDia(_grupos[i]),
    );
  }

  Widget _estadoVacio() {
    final sinFiltro = _filtro == FiltroHistorial.todos;
    final texto = sinFiltro
        ? 'Todavía no hay actividad.\nRegistrá tu primer gasto y lo vas a ver acá.'
        : 'No hay actividad para "${_filtro.etiqueta}".';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history,
            size: 72,
            color: AppColors.primaryContainer,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (sinFiltro)
            SizedBox(
              width: 240,
              child: AppButton.primary(
                size: AppButtonSize.medium,
                leadingIcon: Icons.add,
                showTrailingIcon: false,
                label: 'Registrar gasto',
                onPressed: () async {
                  final creado = await Navigator.pushNamed(
                    context,
                    Rutas.nuevoMovimiento,
                  );
                  if (creado == true) await _cargar();
                },
              ),
            )
          else
            TextButton(
              onPressed: () => _cambiarFiltro(FiltroHistorial.todos),
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  AppSizes.touchTargetMin,
                  AppSizes.touchTargetMin,
                ),
              ),
              child: Text(
                'Ver todos',
                style: AppTypography.bodyLargeSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grupoDia(GrupoDia grupo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Text(
            grupo.titulo,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        for (final evento in grupo.eventos) _tarjetaEvento(evento),
      ],
    );
  }

  // Carga cognitiva: ícono + frase completa + monto + hora, en una sola tarjeta.
  // Nada que recordar ni calcular.
  Widget _tarjetaEvento(Evento evento) {
    final estilo = _estiloDeTipo(evento.tipo);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderCard,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: estilo.fondoIcono,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(estilo.icono, color: estilo.colorIcono, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estilo.frase(evento.descripcion),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (evento.monto != null)
                      Text(
                        formatearBs(evento.monto!),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: estilo.colorMonto,
                        ),
                      ),
                    if (evento.monto != null)
                      Text(
                        ' · ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      evento.hora,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _EstiloEvento _estiloDeTipo(TipoEvento tipo) {
    switch (tipo) {
      case TipoEvento.gastoRegistrado:
        return _EstiloEvento(
          icono: Icons.trending_down,
          colorIcono: AppColors.statusExceeded,
          fondoIcono: AppColors.statusExceededContainer,
          colorMonto: AppColors.statusExceeded,
          frase: (d) =>
              d.isEmpty ? 'Registraste un gasto' : 'Registraste gasto: $d',
        );
      case TipoEvento.ingresoRegistrado:
        return _EstiloEvento(
          icono: Icons.trending_up,
          colorIcono: AppColors.primary,
          fondoIcono: AppColors.statusNormalContainer,
          colorMonto: AppColors.primary,
          frase: (d) =>
              d.isEmpty ? 'Registraste un ingreso' : 'Registraste ingreso: $d',
        );
      case TipoEvento.movimientoPagado:
        return _EstiloEvento(
          icono: Icons.check_circle_outline,
          colorIcono: AppColors.primary,
          fondoIcono: AppColors.statusNormalContainer,
          colorMonto: AppColors.textPrimary,
          frase: (d) => d.isEmpty
              ? 'Marcaste como pagado un movimiento'
              : 'Marcaste como pagado: $d',
        );
      case TipoEvento.limiteDefinido:
        return _EstiloEvento(
          icono: Icons.savings_outlined,
          colorIcono: AppColors.primary,
          fondoIcono: AppColors.statusNormalContainer,
          colorMonto: AppColors.textPrimary,
          frase: (d) => d.isEmpty
              ? 'Definiste tu límite mensual'
              : 'Definiste tu límite: $d',
        );
    }
  }
}

class _EstiloEvento {
  final IconData icono;
  final Color colorIcono;
  final Color fondoIcono;
  final Color colorMonto;
  final String Function(String descripcion) frase;

  const _EstiloEvento({
    required this.icono,
    required this.colorIcono,
    required this.fondoIcono,
    required this.colorMonto,
    required this.frase,
  });
}
