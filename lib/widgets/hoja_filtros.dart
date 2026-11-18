import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../modelos/filtros.dart';
import '../modelos/movimiento.dart';

// Abre el panel y devuelve los filtros elegidos (null si lo cierran sin aplicar)
Future<FiltrosMovimientos?> mostrarHojaFiltros(
  BuildContext context,
  FiltrosMovimientos actual,
) {
  return showModalBottomSheet<FiltrosMovimientos>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _HojaFiltros(actual: actual),
  );
}

class _HojaFiltros extends StatefulWidget {
  final FiltrosMovimientos actual;
  const _HojaFiltros({required this.actual});

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late TipoMovimiento? _tipo = widget.actual.tipo;
  late CategoriaMovimiento? _categoria = widget.actual.categoria;
  late EstadoMovimiento? _estado = widget.actual.estado;
  late PeriodoFiltro? _periodo = widget.actual.periodo;
  late DateTime? _desde = widget.actual.desde;
  late DateTime? _hasta = widget.actual.hasta;
  String? _error;
  // Tipo y Estado se usan poco: quedan plegados, salvo que ya tengan un filtro activo (Hick, clase 16)
  late bool _masFiltros =
      widget.actual.tipo != null || widget.actual.estado != null;

  FiltrosMovimientos _armar() => FiltrosMovimientos(
    buscar: widget.actual.buscar,
    tipo: _tipo,
    categoria: _categoria,
    estado: _estado,
    periodo: _periodo,
    desde: _periodo == PeriodoFiltro.rango ? _desde : null,
    hasta: _periodo == PeriodoFiltro.rango ? _hasta : null,
  );

  void _aplicar() {
    final filtros = _armar();
    final error = filtros.validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, filtros);
  }

  void _limpiar() {
    setState(() {
      _tipo = null;
      _categoria = null;
      _estado = null;
      _periodo = null;
      _desde = null;
      _hasta = null;
      _error = null;
    });
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final inicial = (esDesde ? _desde : _hasta) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() {
      if (esDesde) {
        _desde = elegida;
      } else {
        _hasta = elegida;
      }
      _error = null;
    });
  }

  // Un grupo de opciones; la clave null significa "sin filtro"
  Widget _grupo<T>(
    String titulo,
    Map<T?, String> opciones,
    T? valor,
    ValueChanged<T?> alCambiar,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colores.azulOscuro,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opciones.entries.map((e) {
            final elegido = valor == e.key;
            return ChoiceChip(
              label: Text(e.value),
              selected: elegido,
              showCheckmark: false,
              selectedColor: Colores.verdeClaro,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: elegido ? Colores.verdeOscuro : Colores.azulOscuro,
                fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: elegido ? Colores.verdeOscuro : Colores.verdeClaro,
              ),
              onSelected: (_) => alCambiar(e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Despliega o pliega Tipo y Estado; si están plegados, avisa cuántos tienen un filtro activo
  Widget _botonMasFiltros() {
    final activos = [_tipo, _estado].where((v) => v != null).length;
    final texto = _masFiltros
        ? 'Menos filtros'
        : (activos > 0 ? 'Más filtros ($activos)' : 'Más filtros');
    return TextButton.icon(
      onPressed: () => setState(() => _masFiltros = !_masFiltros),
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      icon: Icon(
        _masFiltros ? Icons.expand_less : Icons.expand_more,
        color: Colores.verdeOscuro,
      ),
      label: Text(
        texto,
        style: const TextStyle(
          color: Colores.verdeOscuro,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _botonFecha(
    String etiqueta,
    DateTime? fecha,
    VoidCallback alPresionar,
  ) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: alPresionar,
        icon: const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: Colores.verdeOscuro,
        ),
        label: Text(
          fecha == null ? etiqueta : Movimiento.formatearFecha(fecha),
          style: const TextStyle(color: Colores.azulOscuro),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colores.verdeClaro),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colores.azulOscuro,
              ),
            ),
            const SizedBox(height: 20),
            // Lo frecuente a la vista: en qué y cuándo se gastó
            _grupo<CategoriaMovimiento>(
              'Categoría',
              <CategoriaMovimiento?, String>{
                null: 'Todas',
                for (final c in CategoriaMovimiento.values) c: c.texto,
              },
              _categoria,
              (v) => setState(() => _categoria = v),
            ),
            _grupo<PeriodoFiltro>(
              'Periodo',
              const <PeriodoFiltro?, String>{
                null: 'Todos',
                PeriodoFiltro.esteMes: 'Este mes',
                PeriodoFiltro.mesAnterior: 'Mes anterior',
                PeriodoFiltro.rango: 'Rango de fechas',
              },
              _periodo,
              (v) => setState(() {
                _periodo = v;
                _error = null;
              }),
            ),
            if (_periodo == PeriodoFiltro.rango) ...[
              Row(
                children: [
                  _botonFecha(
                    'Desde',
                    _desde,
                    () => _elegirFecha(esDesde: true),
                  ),
                  const SizedBox(width: 12),
                  _botonFecha(
                    'Hasta',
                    _hasta,
                    () => _elegirFecha(esDesde: false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Lo que se usa poco, plegado en "Más filtros"
            _botonMasFiltros(),
            const SizedBox(height: 12),
            if (_masFiltros) ...[
              _grupo<TipoMovimiento>(
                'Tipo',
                <TipoMovimiento?, String>{
                  null: 'Todos',
                  for (final t in TipoMovimiento.values) t: t.texto,
                },
                _tipo,
                (v) => setState(() => _tipo = v),
              ),
              _grupo<EstadoMovimiento>(
                'Estado',
                <EstadoMovimiento?, String>{
                  null: 'Todos',
                  for (final e in EstadoMovimiento.values) e: e.texto,
                },
                _estado,
                (v) => setState(() => _estado = v),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colores.rojo),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: _limpiar,
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(color: Colores.verdeOscuro),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _aplicar,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colores.verdeOscuro,
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
