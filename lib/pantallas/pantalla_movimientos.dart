import 'dart:async';

import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../modelos/filtros.dart';
import '../modelos/limite.dart';
import '../modelos/movimiento.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_limite.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/campo_texto.dart';
import '../widgets/hoja_filtros.dart';
import '../widgets/mensajes.dart';
import 'pantalla_nuevo_movimiento.dart';
import '../modelos/presupuesto_categoria.dart';

class PantallaMovimientos extends StatefulWidget {
  const PantallaMovimientos({super.key});

  @override
  State<PantallaMovimientos> createState() => _PantallaMovimientosState();
}

class _PantallaMovimientosState extends State<PantallaMovimientos> {
  String? _nombre;
  List<Movimiento> _movimientos = [];
  TotalesMovimientos? _totales;
  bool _cargandoLista = true;
  ResumenLimite? _resumen;
  List<PresupuestoCategoria> _categorias = [];

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
      if (!mounted || numero != _peticion) return;
      setState(() {
        _movimientos = listado.movimientos;
        _totales = listado.totales;
        _resumen = resumen;
        _categorias = categorias;
        _cargandoLista = false;
      });
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
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: Colores.verdeOscuro),
            onPressed: _cerrarSesion,
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            // Sin límite definido no se muestra
            if (_resumen?.tieneLimite ?? false) ...[
              _tarjetaLimite(_resumen!),
              const SizedBox(height: 16),
            ],
            _barraBusqueda(),
            _filtrosActivos(),
            _lineaTotales(),
            const SizedBox(height: 12),
            Expanded(child: _lista()),
          ],
        ),
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

  // Total de la lista que se está viendo (lo calcula el servidor sobre esa misma lista)
  Widget _lineaTotales() {
    final t = _totales;
    if (t == null || _cargandoLista) return const SizedBox.shrink();

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

  Widget _lista() {
    if (_cargandoLista) {
      return const Center(
        child: CircularProgressIndicator(color: Colores.verdeOscuro),
      );
    }
    if (_movimientos.isEmpty) {
      // Con filtros: ninguno coincide. Sin filtros: aún no hay movimientos.
      if (_filtros.hayFiltros) {
        return Center(
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
        );
      }
      return const Center(
        child: Text(
          'Aún no tienes movimientos.\nCrea el primero con el botón de abajo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colores.grisAzulado,
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _movimientos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _tarjeta(_movimientos[i]),
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
                tooltip: 'Editar',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colores.verdeOscuro,
                ),
                onPressed: () => _editar(m),
              ),
              IconButton(
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
