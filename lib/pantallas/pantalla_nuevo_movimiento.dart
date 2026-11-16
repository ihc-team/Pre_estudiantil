import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../modelos/limite.dart';
import '../modelos/movimiento.dart';
import '../modelos/presupuesto_categoria.dart';
import '../servicios/analitica.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_analitica.dart';
import '../servicios/servicio_limite.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';

class PantallaNuevoMovimiento extends StatefulWidget {
  // Si viene un movimiento, la pantalla funciona en modo edición
  final Movimiento? movimiento;

  const PantallaNuevoMovimiento({super.key, this.movimiento});

  @override
  State<PantallaNuevoMovimiento> createState() =>
      _PantallaNuevoMovimientoState();
}

class _PantallaNuevoMovimientoState extends State<PantallaNuevoMovimiento> {
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  final _fechaTexto = TextEditingController();
  final _nodoMonto = FocusNode();
  DateTime? _fecha;
  TipoMovimiento _tipo = TipoMovimiento.gasto;
  // Sin categoría al crear: la persona la elige (H5.3)
  CategoriaMovimiento? _categoria;
  FrecuenciaRecurrencia? _frecuencia;
  String? _errorCategoria;
  // Errores debajo de cada campo (H9.2)
  String? _errorConcepto;
  String? _errorMonto;
  String? _errorFecha;
  bool _cargando = false;
  ResumenLimite? _resumen;
  List<PresupuestoCategoria> _presupuestosCategorias = [];
  // Mensaje del servidor cuando el gasto supera el límite (422); se queda hasta que la persona actúe
  String? _bloqueoLimite;

  bool get _editando => widget.movimiento != null;
  bool get _montoBloqueado => widget.movimiento?.montoBloqueado ?? false;

  // Foto inicial para saber si hay cambios sin guardar (H3.1)
  String _conceptoInicial = '';
  String _montoInicial = '';
  TipoMovimiento _tipoInicial = TipoMovimiento.gasto;
  CategoriaMovimiento? _categoriaInicial;
  FrecuenciaRecurrencia? _frecuenciaInicial;
  DateTime? _fechaInicial;
  // Tras guardar, salir no pregunta; evita programar la salida dos veces
  bool _salidaPermitida = false;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    if (m != null) {
      _concepto.text = m.concepto;
      _monto.text = m.monto.toStringAsFixed(2);
      _fecha = m.fecha;
      _fechaTexto.text = Movimiento.formatearFecha(m.fecha);
      _tipo = m.tipo;
      _categoria = m.categoria;
      _frecuencia = m.frecuencia;
    } else {
      // Casi siempre se anota lo de hoy: la fecha empieza en hoy y se puede cambiar (H7.1)
      final hoy = DateTime.now();
      _fecha = DateTime(hoy.year, hoy.month, hoy.day);
      _fechaTexto.text = Movimiento.formatearFecha(_fecha!);
    }
    // Se guarda la foto inicial: contra esto se comparan los cambios (H3.1)
    _conceptoInicial = _concepto.text.trim();
    _montoInicial = _monto.text.trim();
    _tipoInicial = _tipo;
    _categoriaInicial = _categoria;
    _frecuenciaInicial = _frecuencia;
    _fechaInicial = _fecha;
    if (widget.movimiento == null) {
      unawaited(
        ServicioAnalitica.track('movimiento_iniciado', {
          'pantalla': 'nuevo_movimiento',
        }),
      );
    }
    _cargarResumen();

    // Analítica: se dispara al abrir el formulario solo para un movimiento nuevo
    if (widget.movimiento == null) {
      AnaliticaServicio.track('movimiento_iniciado', {'tipo': _tipo.name});
    }
  }

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    _fechaTexto.dispose();
    _nodoMonto.dispose();
    super.dispose();
  }

  // H3.1: hay algo escrito o cambiado que se perdería al salir
  bool get _hayCambios {
    return _concepto.text.trim() != _conceptoInicial ||
        _monto.text.trim() != _montoInicial ||
        _tipo != _tipoInicial ||
        _categoria != _categoriaInicial ||
        _frecuencia != _frecuenciaInicial ||
        _fecha != _fechaInicial;
  }

  // Sale del formulario respetando la decisión (conserva el resultado del pop)
  void _salir([Object? resultado]) {
    if (_saliendo) return;
    _saliendo = true;
    setState(() => _salidaPermitida = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, resultado);
    });
  }

  // true = puede salir (sin cambios o descarta); false = sigue editando
  Future<bool> _confirmarSalida() async {
    if (_salidaPermitida || !_hayCambios) return true;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          '¿Descartar los cambios?',
          style: TextStyle(color: Colores.azulOscuro),
        ),
        content: const Text(
          'Tienes datos sin guardar. Si sales ahora, se perderán.',
          style: TextStyle(color: Colores.grisAzulado, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text(
              'Seguir editando',
              style: TextStyle(color: Colores.verdeOscuro),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return descartar ?? false;
  }

  // Sin restricción: se puede elegir cualquier fecha
  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _fechaTexto.text = Movimiento.formatearFecha(elegida);
        _bloqueoLimite = null;
        _errorFecha = null;
      });
      _cargarResumen();
    }
  }

  // Límite del mes de la fecha elegida (sin fecha, el mes actual)
  Future<void> _cargarResumen() async {
    final mes = _fecha == null
        ? null
        : Movimiento.fechaParaServidor(_fecha!).substring(0, 7);
    try {
      final resumen = await ServicioLimite.leer(mes);
      List<PresupuestoCategoria> presupuestos = [];
      try {
        presupuestos = await ServicioLimite.leerPorCategoria(mes);
      } catch (_) {
        // Si es que no es posible leer los presupuestos por categoria, continua con el resumen general
      }
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _presupuestosCategorias = presupuestos;
      });
    } on SesionExpirada {
      // Se vuelve al login al guardar
    } on ErrorAcceso {
      // Sin el aviso igual se puede guardar: el servidor controla el límite
    }
  }

  // Salida 1 del bloqueo: corregir el monto sin borrar lo escrito
  void _cambiarMonto() {
    // Si el campo ya tenía el foco, solo falta volver a abrir el teclado
    if (_nodoMonto.hasFocus) {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      _nodoMonto.requestFocus();
    }
    _monto.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _monto.text.length,
    );
  }

  // Salida 2 del bloqueo: subir el límite y volver con el restante actualizado
  Future<void> _subirLimite() async {
    await Navigator.pushNamed(context, Rutas.limite);
    if (!mounted) return;
    setState(() => _bloqueoLimite = null);
    await _cargarResumen();
  }

  // Bloqueo por límite con sus dos salidas (H9.1)
  Widget _avisoBloqueo(String mensaje) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colores.rojo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mensaje,
            style: const TextStyle(
              color: Colores.rojo,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _cambiarMonto,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colores.verdeOscuro,
                ),
                label: const Text(
                  'Cambiar monto',
                  style: TextStyle(color: Colores.verdeOscuro),
                ),
              ),
              TextButton.icon(
                onPressed: _subirLimite,
                icon: const Icon(
                  Icons.savings_outlined,
                  color: Colores.verdeOscuro,
                ),
                label: const Text(
                  'Subir límite',
                  style: TextStyle(color: Colores.verdeOscuro),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Debajo del monto, cuanto queda del limite y cuanto quedaria con este gasto
  Widget? _avisoLimite() {
    final r = _resumen;
    if (_tipo != TipoMovimiento.gasto ||
        _montoBloqueado ||
        r == null ||
        !r.tieneLimite) {
      return null;
    }
    // Al editar, el monto anterior se descuenta solo si es del mismo mes
    final original = widget.movimiento;
    final montoAnterior =
        original != null &&
            Movimiento.fechaParaServidor(original.fecha).startsWith(r.mes!)
        ? original.monto
        : 0.0;
    final aviso = avisoGasto(
      r,
      double.tryParse(_monto.text.trim().replaceAll(',', '.')),
      montoAnterior: montoAnterior,
    );
    final color = aviso.seExcede ? Colores.rojo : Colores.grisAzulado;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.savings_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              aviso.texto,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: aviso.seExcede
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Verifica si el gasto excede el limite de su categoria y mes
  Map<String, dynamic>? _verificarExcesoCategoria(double montoNuevo) {
    if (_tipo != TipoMovimiento.gasto || _categoria == null) return null;

    final nombreCat = _categoria!.name;
    final coincidencia = _presupuestosCategorias.where(
      (p) => p.categoria.toLowerCase() == nombreCat.toLowerCase(),
    );
    if (coincidencia.isEmpty) return null;

    final presupuesto = coincidencia.first;
    if (!presupuesto.tieneLimite) return null;

    final limite = presupuesto.limite!;
    var gastado = presupuesto.gastado;

    // Si es que se esta editando y el movimiento previo ya era gasto en esta categoria, se descuenta su monto previo
    if (_editando &&
        widget.movimiento!.tipo == TipoMovimiento.gasto &&
        widget.movimiento!.categoria?.name.toLowerCase() ==
            nombreCat.toLowerCase()) {
      gastado = (gastado - widget.movimiento!.monto).clamp(
        0.0,
        double.infinity,
      );
    }

    final totalResultante = gastado + montoNuevo;
    if (totalResultante > limite) {
      final exceso = totalResultante - limite;
      return {
        'presupuesto': presupuesto,
        'exceso': exceso,
        'categoriaTexto': _categoria!.texto,
      };
    }
    return null;
  }

  // Diálogo accesible para avisar antes de superar el límite
  Future<bool> _pedirConfirmacionSuperacionLimite({
    required String categoriaTexto,
    required String categoriaName,
    required double exceso,
  }) async {
    // Analítica: se advierte al usuario
    AnaliticaServicio.track('aviso_limite_mostrado', {
      'categoria': categoriaName,
    });

    final excesoTexto = 'Bs ${exceso.toStringAsFixed(2).replaceAll('.', ',')}';

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (contexto) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colores.rojo, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vas a superar el límite',
                style: TextStyle(
                  color: Colores.azulOscuro,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Con este gasto superarás el límite de la categoría $categoriaTexto por $excesoTexto.\n\nPuedes regresar para ajustar el monto o confirmar si decides registrarlo de todas formas.',
          style: const TextStyle(
            color: Colores.grisAzulado,
            height: 1.4,
            fontSize: 15,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          // El principio de simetria (Anti patron #2)
          // Botones con el mismo peso visual, misma altura y sin textos que culpen.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(contexto, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colores.azulOscuro,
                      side: const BorderSide(color: Colores.grisAzulado),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Seguir editando',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(contexto, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colores.verdeOscuro,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirmar gasto',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final resultado = confirmado ?? false;
    if (resultado) {
      AnaliticaServicio.track('aviso_limite_confirmado', {
        'categoria': categoriaName,
      });
    } else {
      AnaliticaServicio.track('aviso_limite_cancelado', {
        'categoria': categoriaName,
      });
    }
    return resultado;
  }

  Future<void> _guardar() async {
    final concepto = _concepto.text.trim();
    final textoMonto = _monto.text.trim().replaceAll(',', '.');

    final monto = double.tryParse(textoMonto);

    // Cada error va debajo de su campo, todos a la vez
    setState(() {
      _errorCategoria = _categoria == null ? 'Elige una categoría' : null;
      _errorConcepto = concepto.isEmpty ? mensajeCampoVacio : null;
      _errorMonto = textoMonto.isEmpty
          ? mensajeCampoVacio
          : (monto == null || monto <= 0 ? 'Escribe un monto mayor a 0' : null);
      _errorFecha = _fecha == null ? mensajeCampoVacio : null;
    });
    if (_errorCategoria != null ||
        _errorConcepto != null ||
        _errorMonto != null ||
        _errorFecha != null) {
      // Analitica, registrar el primer motivo fijo de error que freno al usuario
      String motivo = 'validacion_invalida';
      if (_errorConcepto != null) {
        motivo = 'concepto_vacio';
      } else if (textoMonto.isEmpty) {
        motivo = 'monto_vacio';
      } else if (monto == null || monto <= 0) {
        motivo = 'monto_invalido';
      } else if (_errorCategoria != null) {
        motivo = 'categoria_vacia';
      } else if (_errorFecha != null) {
        motivo = 'fecha_vacia';
      }
      AnaliticaServicio.track('error_formulario_mostrado', {'motivo': motivo});
      return;
    }

    // Parte B: Aviso antes de superar el límite de la categoría (nuevos y editados)
    final avisoExceso = _verificarExcesoCategoria(monto!);
    if (avisoExceso != null) {
      final confirmado = await _pedirConfirmacionSuperacionLimite(
        categoriaTexto: avisoExceso['categoriaTexto'] as String,
        categoriaName:
            (avisoExceso['presupuesto'] as PresupuestoCategoria).categoria,
        exceso: avisoExceso['exceso'] as double,
      );
      if (!confirmado) {
        // Cancelar no cambia nada y deja seguir editando
        return;
      }
    }

    setState(() => _cargando = true);
    try {
      if (_editando) {
        await ServicioMovimientos.editar(
          widget.movimiento!,
          concepto,
          monto!,
          _fecha!,
          _categoria!,
        );
      } else {
        await ServicioMovimientos.crear(
          concepto,
          monto!,
          _fecha!,
          _tipo,
          _categoria!,
          recurrente: _frecuencia != null,
          frecuencia: _frecuencia,
        );

        // Analítica: se dispara UNA sola vez, solo DESPUÉS de confirmado en la base de datos
        AnaliticaServicio.track('movimiento_guardado', {'tipo': _tipo.name});
      }
      if (!mounted) return;
      mostrarMensaje(
        context,
        _editando
            ? 'Cambios guardados'
            : (_frecuencia != null
                  ? 'Gasto recurrente guardado'
                  : 'Movimiento guardado'),
      );
      _salidaPermitida = true; // tras guardar, salir no pregunta (H3.1)
      Navigator.pop(context, true); // true = hay que refrescar la lista
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      if (e.codigo == 422) {
        setState(() => _bloqueoLimite = e.mensaje);
      } else {
        mostrarMensaje(context, e.mensaje, esError: true);
      }
    } on StateError catch (e) {
      // Regla del modelo (por ejemplo, monto bloqueado)
      if (!mounted) return;
      mostrarMensaje(context, e.message, esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Opciones en chips. Si alCambiar es null, quedan deshabilitadas. valor null = ninguna elegida.
  Widget _selector<T>(
    String titulo,
    Map<T, String> opciones,
    T? valor,
    ValueChanged<T>? alCambiar, {
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colores.grisAzulado,
            ),
          ),
        ),
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
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: elegido ? Colores.verdeOscuro : Colores.azulOscuro,
                fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: elegido ? Colores.verdeOscuro : Colores.verdeClaro,
              ),
              onSelected: alCambiar == null ? null : (_) => alCambiar(e.key),
            );
          }).toList(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Text(
              error,
              style: const TextStyle(fontSize: 13, color: Colores.rojo),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si hay bloqueo, el recuadro con salidas reemplaza al aviso
    final aviso = _bloqueoLimite != null
        ? _avisoBloqueo(_bloqueoLimite!)
        : _avisoLimite();

    // H3.1: la flecha atrás (y el botón del sistema) avisan si hay cambios
    return PopScope(
      canPop: _salidaPermitida,
      onPopInvokedWithResult: (salio, resultado) async {
        if (salio || !mounted) return;
        if (await _confirmarSalida()) _salir(resultado);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colores.azulOscuro,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  _editando ? 'Editar movimiento' : 'Nuevo movimiento',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colores.azulOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _editando
                      ? 'Modifica los datos y guarda.'
                      : (_tipo == TipoMovimiento.ingreso
                            ? 'Se guardará como por cobrar.'
                            : 'Se guardará como pendiente.'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colores.grisAzulado,
                  ),
                ),
                const SizedBox(height: 32),
                _selector<TipoMovimiento>(
                  _editando ? 'Tipo (no se puede cambiar)' : 'Tipo',
                  {for (final t in TipoMovimiento.values) t: t.texto},
                  _tipo,
                  _editando
                      ? null
                      : (v) => setState(() {
                          _tipo = v;
                          if (v == TipoMovimiento.ingreso) {
                            _frecuencia = null;
                          }
                        }),
                ),
                if (!_editando && _tipo == TipoMovimiento.gasto) ...[
                  const SizedBox(height: 20),
                  _selector<String>(
                    'Recurrencia',
                    const {
                      'no': 'No repetir',
                      'semanal': 'Semanal',
                      'mensual': 'Mensual',
                    },
                    _frecuencia?.name ?? 'no',
                    (v) => setState(() {
                      _frecuencia = v == 'no'
                          ? null
                          : FrecuenciaRecurrencia.values.byName(v);
                    }),
                  ),
                ],
                const SizedBox(height: 20),
                _selector<CategoriaMovimiento>(
                  'Categoría',
                  {for (final c in CategoriaMovimiento.values) c: c.texto},
                  _categoria,
                  (v) => setState(() {
                    _categoria = v;
                    _errorCategoria = null;
                  }),
                  error: _errorCategoria,
                ),
                const SizedBox(height: 20),
                CampoTexto(
                  controlador: _concepto,
                  etiqueta: 'Concepto',
                  icono: Icons.description_outlined,
                  error: _errorConcepto,
                  alCambiar: (_) {
                    if (_errorConcepto != null) {
                      setState(() => _errorConcepto = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _monto,
                  etiqueta: 'Monto (Bs)',
                  // H2.3: ícono neutro de dinero; el $ sugería dólares y la app usa Bs
                  icono: _montoBloqueado
                      ? Icons.lock_outline
                      : Icons.payments_outlined,
                  tipoTeclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // Si está bloqueado: solo lectura, y al tocarlo se explica el motivo
                  soloLectura: _montoBloqueado,
                  nodoFoco: _nodoMonto,
                  error: _errorMonto,
                  // Recalcula el aviso del límite mientras se escribe; al corregir, se van el bloqueo y el error
                  alCambiar: (_) => setState(() {
                    _bloqueoLimite = null;
                    _errorMonto = null;
                  }),
                  alTocar: _montoBloqueado
                      ? () => mostrarMensaje(
                          context,
                          widget.movimiento?.motivoMontoBloqueadoTexto ??
                              Movimiento.motivoMontoBloqueado,
                          esError: true,
                        )
                      : null,
                ),
                if (_montoBloqueado)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colores.grisAzulado,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.movimiento?.motivoMontoBloqueadoTexto ??
                                Movimiento.motivoMontoBloqueado,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colores.grisAzulado,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ?aviso,
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _fechaTexto,
                  etiqueta: 'Fecha',
                  icono: Icons.calendar_today_outlined,
                  soloLectura: true,
                  alTocar: _elegirFecha,
                  error: _errorFecha,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 58,
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colores.verdeOscuro,
                          ),
                        )
                      : BotonPildora(
                          texto: _editando ? 'Guardar cambios' : 'Guardar',
                          icono: Icons.check,
                          alPresionar: _guardar,
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
