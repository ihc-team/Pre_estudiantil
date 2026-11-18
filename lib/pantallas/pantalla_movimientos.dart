import 'dart:async';

import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../modelos/filtros.dart';
import '../modelos/limite.dart';
import '../modelos/meta_ahorro.dart';
import '../modelos/movimiento.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_cuenta.dart';
import '../servicios/servicio_limite.dart';
import '../servicios/servicio_metas.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/campo_texto.dart';
import '../widgets/hoja_filtros.dart';
import '../widgets/mensajes.dart';
import 'pantalla_nuevo_movimiento.dart';
import '../modelos/presupuesto_categoria.dart';
import '../servicios/analitica.dart';

enum _VistaMovimientos { todos, pendientes, pagados, recurrentes }

class PantallaMovimientos extends StatefulWidget {
  const PantallaMovimientos({super.key});

  @override
  State<PantallaMovimientos> createState() => _PantallaMovimientosState();
}

class _PantallaMovimientosState extends State<PantallaMovimientos> {
  String? _nombre;
  List<Movimiento> _movimientos = [];
  bool _cargandoLista = true;
  ResumenLimite? _resumen;
  ResumenMetas? _resumenMetas;
  List<PresupuestoCategoria> _categorias = [];
  _VistaMovimientos _vista = _VistaMovimientos.todos;

  // Búsqueda y filtros (#7)
  FiltrosMovimientos _filtros = FiltrosMovimientos.vacio;
  final _buscador = TextEditingController();
  Timer? _espera;
  int _peticion = 0; // para ignorar respuestas viejas si se escribe rápido

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  // Protección de la ruta: si no hay sesión válida, vuelve al login
  Future<void> _verificarSesion() async {
    String? nombre;
    try {
      nombre = await ServicioAcceso.obtenerNombreSesion();
    } on ErrorAcceso {
      nombre = null;
    }

    if (!mounted) return;
    if (nombre == null) {
      Navigator.pushReplacementNamed(context, Rutas.login);
      return;
    }
    setState(() => _nombre = nombre);
    await _cargarMovimientos();
  }

  void _volverAlLogin() {
    Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
  }

  // Recuperar: lee lo guardado (con los filtros activos) y la tarjeta del límite
  Future<void> _cargarMovimientos() async {
    final numero = ++_peticion;
    try {
      final listado = await ServicioMovimientos.listar(_filtros);
      final resumen = await ServicioLimite.leer();
      final categorias = await ServicioLimite.leerPorCategoria();

      ResumenMetas? resumenMetas;
      try {
        final metas = await ServicioMetas.listar();
        resumenMetas = metas.resumen;
      } on SesionExpirada {
        rethrow;
      } on ErrorAcceso {
        // La pantalla sigue funcionando aunque falle el resumen de metas.
      }

      if (!mounted || numero != _peticion) return;
      setState(() {
        _movimientos = listado.movimientos;
        _resumen = resumen;
        _resumenMetas = resumenMetas;
        _categorias = categorias;
        _cargandoLista = false;
      });

      // Analitica, si hay filtros o texto de busqueda y la lista da 0 resultados
      if (_movimientos.isEmpty && _filtros.hayFiltros) {
        final origen = _filtros.buscar.isNotEmpty ? 'texto' : 'filtros';
        AnaliticaServicio.track('busqueda_sin_resultados', {'origen': origen});
      }
    } on SesionExpirada {
      if (!mounted) return;
      _volverAlLogin();
    } on ErrorAcceso catch (e) {
      if (!mounted || numero != _peticion) return;
      setState(() => _cargandoLista = false);
      mostrarMensaje(context, e.mensaje, esError: true);
    }
  }

  // Busca 400 ms después de la última letra, para no consultar en cada tecla
  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _filtros = _filtros.conBuscar(texto));
      _cargarMovimientos();
    });
  }

  Future<void> _abrirFiltros() async {
    // Se aplica antes lo que haya escrito en el buscador
    _espera?.cancel();
    _filtros = _filtros.conBuscar(_buscador.text);

    final nuevos = await mostrarHojaFiltros(context, _filtros);
    if (nuevos == null || !mounted) return;
    setState(() => _filtros = nuevos);
    await _cargarMovimientos();
  }

  Future<void> _quitarFiltro(ClaveFiltro clave) async {
    if (clave == ClaveFiltro.buscar) {
      _espera?.cancel();
      _buscador.clear();
    }
    setState(() => _filtros = _filtros.quitar(clave));
    await _cargarMovimientos();
  }

  Future<void> _quitarTodos() async {
    _espera?.cancel();
    _buscador.clear();
    setState(() => _filtros = FiltrosMovimientos.vacio);
    await _cargarMovimientos();
  }

  Future<void> _abrirFormulario() async {
    final creado = await Navigator.pushNamed(context, Rutas.nuevoMovimiento);
    if (creado == true) await _cargarMovimientos();
  }

  Future<void> _abrirLimite() async {
    // Se recarga siempre: se puede volver con "Listo" o con la flecha atrás
    await Navigator.pushNamed(context, Rutas.limite);
    await _cargarMovimientos();
  }

  Future<void> _abrirHistorial() async {
    await Navigator.pushNamed(context, Rutas.historial);
  }

  Future<void> _abrirMisDatos() async {
    final resultado = await Navigator.pushNamed(context, Rutas.misDatos);
    if (resultado == 'solicitar_eliminar') {
      unawaited(_eliminarCuenta());
    }
  }

  // Future<void> _abrirAnalitica() async {
  //   await Navigator.pushNamed(context, Rutas.analitica);
  // }

  Future<void> _abrirMetas() async {
    await Navigator.pushNamed(context, Rutas.metas);
    await _cargarMovimientos();
  }

  // Editar: abre el mismo formulario con los datos del movimiento
  Future<void> _editar(Movimiento movimiento) async {
    final cambiado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaNuevoMovimiento(movimiento: movimiento),
      ),
    );
    if (cambiado == true) await _cargarMovimientos();
  }

  // Ventana de confirmación reutilizable
  Future<bool> _pedirConfirmacion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    bool esPeligro = false,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(titulo, style: const TextStyle(color: Colores.azulOscuro)),
        content: Text(
          mensaje,
          style: const TextStyle(color: Colores.grisAzulado, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colores.verdeOscuro),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: FilledButton.styleFrom(
              backgroundColor: esPeligro
                  ? Colors.red.shade700
                  : Colores.verdeOscuro,
            ),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );
    // Si cierran el diálogo tocando fuera, el resultado es null: se trata como cancelar
    return confirmado ?? false;
  }

  Future<void> _marcarComoPagado(Movimiento movimiento) async {
    // H2.1: el ingreso se cobra, el gasto se paga
    final accion = movimiento.accionMarcarTexto;
    final participio = movimiento.esIngreso ? 'cobrado' : 'pagado';
    final confirmado = await _pedirConfirmacion(
      titulo: accion,
      mensaje:
          '¿Deseas marcar este movimiento como $participio? Esta acción no se puede deshacer.',
      textoConfirmar: 'Confirmar',
    );
    if (!confirmado || !mounted) return;

    try {
      await ServicioMovimientos.marcarComoPagado(movimiento);
      if (!mounted) return;
      mostrarMensaje(context, 'Marcado como $participio');
      await _cargarMovimientos();
    } on SesionExpirada {
      if (!mounted) return;
      _volverAlLogin();
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } on StateError catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.message, esError: true);
    }
  }

  Future<void> _eliminar(Movimiento movimiento) async {
    final confirmado = await _pedirConfirmacion(
      titulo: 'Eliminar movimiento',
      mensaje:
          '¿Deseas eliminar "${movimiento.concepto}"? Esta acción no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      esPeligro: true,
    );
    if (!confirmado || !mounted) return;

    try {
      await ServicioMovimientos.eliminar(movimiento);
      if (!mounted) return;
      mostrarMensaje(context, 'Movimiento eliminado');
      await _cargarMovimientos();
    } on SesionExpirada {
      if (!mounted) return;
      _volverAlLogin();
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    }
  }

  // H3.3: un toque accidental ya no saca a la persona de su cuenta
  Future<void> _cerrarSesion() async {
    final confirmado = await _pedirConfirmacion(
      titulo: '¿Cerrar sesión?',
      mensaje: '¿Deseas cerrar tu sesión? Tendrás que iniciar sesión de nuevo para entrar.',
      textoConfirmar: 'Cerrar sesión',
    );
    if (!confirmado || !mounted) return;
    await ServicioAcceso.cerrarSesion();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Rutas.inicio, (ruta) => false);
  }

  Future<void> _eliminarCuenta() async {
    // Analitica, se inicia la intencion de eliminar cuenta
    AnaliticaServicio.track('cuenta_eliminacion_iniciada', {});

    final contrasena = await _pedirContrasenaEliminarCuenta();
    if (contrasena == null) return;

    try {
      await ServicioCuenta.eliminar(contrasena);
      // Analiticam confirmacion exitosa de eliminacion
      AnaliticaServicio.track('cuenta_eliminada', {});
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    }
  }

  Future<String?> _pedirContrasenaEliminarCuenta() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (contexto) => const _DialogoConfirmarEliminar(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se verifica la sesión no se muestra contenido privado
    if (_nombre == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colores.verdeOscuro),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis movimientos'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colores.azulOscuro,
        actions: [
          // Fitts (Tarea 4): acceso visible y alcanzable al Historial
          TextButton.icon(
            onPressed: _abrirHistorial,
            icon: const Icon(Icons.history, color: Colores.verdeOscuro),
            label: const Text(
              'Historial',
              style: TextStyle(color: Colores.verdeOscuro),
            ),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          // H6.1: ícono + texto visible, sin depender del tooltip
          TextButton.icon(
            onPressed: _abrirLimite,
            icon: const Icon(
              Icons.savings_outlined,
              color: Colores.verdeOscuro,
            ),
            label: const Text(
              'Límite',
              style: TextStyle(color: Colores.verdeOscuro),
            ),
          ),
          // Analítica: acceso visible y alcanzable desde la app
          // TextButton.icon(
          //   onPressed: _abrirAnalitica,
          //   icon: const Icon(
          //     Icons.analytics_outlined,
          //     color: Colores.verdeOscuro,
          //   ),
          //   label: const Text(
          //     'Analítica',
          //     style: TextStyle(color: Colores.verdeOscuro),
          //   ),
          //   style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          // ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: Colores.verdeOscuro),
            onPressed: _cerrarSesion,
          ),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            icon: const Icon(Icons.more_vert, color: Colores.verdeOscuro),
            onSelected: (valor) {
              if (valor == 'datos') {
                unawaited(_abrirMisDatos());
              } else if (valor == 'eliminar') {
                unawaited(_eliminarCuenta());
              }
            },
            itemBuilder: (contexto) => const [
              PopupMenuItem(
                value: 'datos',
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_shared_outlined,
                      size: 20,
                      color: Colores.azulOscuro,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Mis datos',
                      style: TextStyle(
                        color: Colores.azulOscuro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colores.grisAzulado,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Eliminar cuenta',
                      style: TextStyle(color: Colores.azulOscuro),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: Colores.verdeOscuro,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo movimiento'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        children: [
          Text(
            'Hola, $_nombre',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colores.azulOscuro,
            ),
          ),
          const SizedBox(height: 16),
          // Sin limite definido no se muestra
          if (_resumen?.tieneLimite ?? false) ...[
            _tarjetaLimite(_resumen!),
            const SizedBox(height: 16),
          ],
          if (_resumenMetas != null) ...[
            _tarjetaMetas(),
            const SizedBox(height: 16),
          ],
          _chipsVista(),
          const SizedBox(height: 8),
          _barraBusqueda(),
          _filtrosActivos(),
          _lineaTotales(),
          const SizedBox(height: 12),
          ..._elementosLista(),
        ],
      ),
    );
  }

  // Buscador por concepto + botón de filtros (con la cantidad de filtros aplicados)
  Widget _barraBusqueda() {
    final cantidad = _filtros.activos
        .where((a) => a.clave != ClaveFiltro.buscar)
        .length;

    return Row(
      children: [
        Expanded(
          child: CampoTexto(
            controlador: _buscador,
            etiqueta: 'Buscar por concepto',
            icono: Icons.search,
            alCambiar: _alEscribir,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Filtros',
          onPressed: _abrirFiltros,
          icon: Badge(
            isLabelVisible: cantidad > 0,
            label: Text('$cantidad'),
            backgroundColor: Colores.verdeOscuro,
            child: const Icon(Icons.tune, color: Colores.verdeOscuro, size: 28),
          ),
        ),
      ],
    );
  }

  // Los filtros aplicados, cada uno con su X para quitarlo
  Widget _filtrosActivos() {
    final activos = _filtros.activos;
    if (activos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final a in activos)
            InputChip(
              label: Text(a.texto),
              onDeleted: () => _quitarFiltro(a.clave),
              backgroundColor: Colores.verdeClaro,
              deleteIconColor: Colores.verdeOscuro,
              side: BorderSide.none,
              labelStyle: const TextStyle(
                color: Colores.verdeOscuro,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (activos.length > 1)
            TextButton(
              onPressed: _quitarTodos,
              child: const Text(
                'Quitar todos',
                style: TextStyle(color: Colores.verdeOscuro),
              ),
            ),
        ],
      ),
    );
  }

  List<Movimiento> get _visibles {
    switch (_vista) {
      case _VistaMovimientos.todos:
        return _movimientos;
      case _VistaMovimientos.pendientes:
        return _movimientos
            .where((m) => m.estado == EstadoMovimiento.pendiente)
            .toList();
      case _VistaMovimientos.pagados:
        return _movimientos
            .where((m) => m.estado == EstadoMovimiento.pagado)
            .toList();
      case _VistaMovimientos.recurrentes:
        return _movimientos.where((m) => m.recurrente).toList();
    }
  }

  TotalesMovimientos _totalesDe(List<Movimiento> movimientos) {
    var ingresos = 0.0;
    var gastos = 0.0;
    for (final movimiento in movimientos) {
      if (movimiento.esIngreso) {
        ingresos += movimiento.monto;
      } else {
        gastos += movimiento.monto;
      }
    }
    return TotalesMovimientos(
      cantidad: movimientos.length,
      ingresos: ingresos,
      gastos: gastos,
    );
  }

  Widget _chipsVista() {
    return Wrap(
      spacing: 8,
      children: [
        _chipVista('Todos', _VistaMovimientos.todos),
        _chipVista('Pendientes', _VistaMovimientos.pendientes),
        _chipVista('Pagados', _VistaMovimientos.pagados),
        _chipVista('Recurrentes', _VistaMovimientos.recurrentes),
      ],
    );
  }

  Widget _chipVista(String texto, _VistaMovimientos vista) {
    final elegido = _vista == vista;
    return ChoiceChip(
      label: Text(texto),
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
      onSelected: (_) => setState(() => _vista = vista),
    );
  }

  // Total de la lista visible según el chip seleccionado
  Widget _lineaTotales() {
    final t = _totalesDe(_visibles);
    if (_cargandoLista) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            '${t.cantidad} ${t.cantidad == 1 ? 'movimiento' : 'movimientos'}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colores.azulOscuro,
            ),
          ),
          Text(
            'Ingresos ${formatearBs(t.ingresos)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colores.verdeOscuro,
            ),
          ),
          Text(
            'Gastos ${formatearBs(t.gastos)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colores.rojo,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _elementosLista() {
    if (_cargandoLista) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: Colores.verdeOscuro),
          ),
        ),
      ];
    }

    final movimientos = _visibles;
    if (movimientos.isEmpty) {
      if (_filtros.hayFiltros) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ningún movimiento coincide\ncon la búsqueda o los filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colores.grisAzulado,
                      height: 1.5,
                    ),
                  ),
                  TextButton(
                    onPressed: _quitarTodos,
                    child: const Text(
                      'Quitar filtros',
                      style: TextStyle(color: Colores.verdeOscuro),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      }

      if (_vista == _VistaMovimientos.recurrentes) {
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No tienes gastos recurrentes.\nCrea uno desde Nuevo movimiento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colores.grisAzulado,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ];
      }

      if (_vista == _VistaMovimientos.pendientes) {
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No tienes movimientos pendientes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colores.grisAzulado,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ];
      }

      if (_vista == _VistaMovimientos.pagados) {
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No tienes movimientos pagados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colores.grisAzulado,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ];
      }

      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'Aún no tienes movimientos.\nCrea el primero con el botón de abajo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colores.grisAzulado,
                height: 1.5,
              ),
            ),
          ),
        ),
      ];
    }

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final grupos = <String, List<Movimiento>>{
      'Vencidos': [],
      'Hoy': [],
      'Próximos': [],
      'Anteriores': [],
    };

    for (final movimiento in movimientos) {
      final fecha = DateTime(
        movimiento.fecha.year,
        movimiento.fecha.month,
        movimiento.fecha.day,
      );

      if (fecha.isBefore(hoy)) {
        if (movimiento.estado == EstadoMovimiento.pendiente) {
          grupos['Vencidos']!.add(movimiento);
        } else {
          grupos['Anteriores']!.add(movimiento);
        }
      } else if (fecha.isAtSameMomentAs(hoy)) {
        grupos['Hoy']!.add(movimiento);
      } else {
        grupos['Próximos']!.add(movimiento);
      }
    }

    final widgets = <Widget>[];
    for (final grupo in grupos.entries) {
      if (grupo.value.isEmpty) continue;

      if (grupo.key == 'Próximos') {
        grupo.value.sort((a, b) => a.fecha.compareTo(b.fecha));
      } else {
        grupo.value.sort((a, b) => b.fecha.compareTo(a.fecha));
      }

      widgets.add(_encabezadoGrupo(grupo.key, grupo.value.length));
      for (final movimiento in grupo.value) {
        widgets.add(_tarjeta(movimiento));
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  Widget _encabezadoGrupo(String titulo, int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        '$titulo ($cantidad)',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colores.azulOscuro,
        ),
      ),
    );
  }

  Widget _tarjetaMetas() {
    final resumen = _resumenMetas!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colores.verdeClaro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: Colores.verdeOscuro),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Metas de ahorro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.azulOscuro,
                  ),
                ),
              ),
              TextButton(
                onPressed: _abrirMetas,
                child: const Text(
                  'Ver metas',
                  style: TextStyle(color: Colores.verdeOscuro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Disponible ${resumen.disponibleTexto}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colores.verdeOscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reservado ${resumen.reservadoTexto}',
            style: const TextStyle(color: Colores.grisAzulado),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaLimite(ResumenLimite r) {
    final color = r.enAviso ? Colores.aviso : Colores.verdeOscuro;
    final restante = r.restante!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: r.enAviso ? Colores.aviso : Colores.verdeClaro,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastado ${formatearBs(r.gastado)} de ${formatearBs(r.limite!)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.azulOscuro,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: r.proporcion,
              minHeight: 8,
              color: color,
              backgroundColor: Colores.verdeClaro,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            restante >= 0
                ? 'Te quedan ${formatearBs(restante)}'
                : 'Te pasaste por ${formatearBs(-restante)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),

          // Lanza aviso por categoria
          for (final cat in _categorias.where((c) => c.excedido)) ...[
            const SizedBox(height: 6),
            Text(
              'Atencion: Te pasaste en ${cat.categoria} por ${formatearBs(-cat.restante!)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjeta(Movimiento m) {
    final pagado = m.estado == EstadoMovimiento.pagado;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colores.verdeClaro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.concepto,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colores.azulOscuro,
                  ),
                ),
              ),
              Text(
                m.montoTexto,
                // H4.2: verde para ingresos y rojo para gastos, igual que los totales
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: m.esIngreso ? Colores.verdeOscuro : Colores.rojo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${m.tipo.texto} · ${m.categoria.texto} · ${m.fechaTexto}',
            style: const TextStyle(color: Colores.grisAzulado),
          ),
          if (m.recurrente) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.repeat, size: 16, color: Colores.verdeOscuro),
                const SizedBox(width: 4),
                Text(
                  m.recurrenciaTexto,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colores.verdeOscuro,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pagado ? Colores.verdeClaro : const Color(0xFFFFE9C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  m.estadoTexto,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: pagado
                        ? Colores.verdeOscuro
                        : const Color(0xFF8A5A00),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('editar-${m.concepto}'),
                tooltip: 'Editar',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colores.verdeOscuro,
                ),
                onPressed: () => _editar(m),
              ),
              IconButton(
                key: ValueKey('eliminar-${m.concepto}'),
                tooltip: 'Eliminar',
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                onPressed: () => _eliminar(m),
              ),
            ],
          ),
          // La acción de pagar/cobrar solo existe mientras esté pendiente
          if (!pagado)
            TextButton(
              onPressed: () => _marcarComoPagado(m),
              child: Text(
                m.accionMarcarTexto,
                style: const TextStyle(color: Colores.verdeOscuro),
              ),
            ),
        ],
      ),
    );
  }
}

class _DialogoConfirmarEliminar extends StatefulWidget {
  const _DialogoConfirmarEliminar();

  @override
  State<_DialogoConfirmarEliminar> createState() =>
      _DialogoConfirmarEliminarState();
}

class _DialogoConfirmarEliminarState extends State<_DialogoConfirmarEliminar> {
  late final TextEditingController _controlador;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: const [
          Icon(Icons.info_outline, color: Colores.azulOscuro, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Eliminar cuenta y datos',
              style: TextStyle(
                color: Colores.azulOscuro,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción eliminará de forma permanente tu cuenta, todos tus movimientos, metas y presupuestos.',
              style: TextStyle(
                color: Colores.azulOscuro,
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colores.verdeClaro.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.download_rounded,
                    color: Colores.verdeOscuro,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Te recomendamos descargar una copia de tus datos antes de continuar.',
                      style: TextStyle(
                        color: Colores.verdeOscuro,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Para confirmar, escribe tu contraseña:',
              style: TextStyle(color: Colores.grisAzulado, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controlador,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colores.azulOscuro,
                    side: const BorderSide(color: Colores.grisAzulado),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
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
                  style: FilledButton.styleFrom(
                    backgroundColor: Colores.azulOscuro,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (_controlador.text.isEmpty) {
                      setState(() => _error = 'Escribe tu contraseña');
                      return;
                    }
                    Navigator.pop(context, _controlador.text);
                  },
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
