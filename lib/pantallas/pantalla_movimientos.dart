import 'dart:async';

import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
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
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderModal),
        title: Text(
          titulo,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          mensaje,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  esPeligro ? AppColors.error : AppColors.primary,
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
      mensaje:
          '¿Deseas cerrar tu sesión? Tendrás que iniciar sesión de nuevo para entrar.',
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
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis movimientos'),
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          // Fitts (Tarea 4): acceso visible y alcanzable al Historial
          TextButton.icon(
            onPressed: _abrirHistorial,
            icon: const Icon(Icons.history, color: AppColors.primary),
            label: const Text(
              'Historial',
              style: TextStyle(color: AppColors.primary),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSizes.touchTargetMin),
            ),
          ),
          // H6.1: ícono + texto visible, sin depender del tooltip
          TextButton.icon(
            onPressed: _abrirLimite,
            icon: const Icon(
              Icons.savings_outlined,
              color: AppColors.primary,
            ),
            label: const Text(
              'Límite',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          // Analítica: acceso visible y alcanzable desde la app
          // TextButton.icon(
          //   onPressed: _abrirAnalitica,
          //   icon: const Icon(
          //     Icons.analytics_outlined,
          //     color: AppColors.primary,
          //   ),
          //   label: const Text(
          //     'Analítica',
          //     style: TextStyle(color: AppColors.primary),
          //   ),
          //   style: TextButton.styleFrom(
          //     minimumSize: const Size(0, AppSizes.touchTargetMin),
          //   ),
          // ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: _cerrarSesion,
          ),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
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
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Mis datos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Eliminar cuenta',
                      style: TextStyle(color: AppColors.textPrimary),
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
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo movimiento'),
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
            Text(
              'Hola, $_nombre',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Sin límite definido no se muestra
            if (_resumen?.tieneLimite ?? false) ...[
              _tarjetaLimite(_resumen!),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_resumenMetas != null) ...[
              _tarjetaMetas(),
              const SizedBox(height: AppSpacing.lg),
            ],
            _chipsVista(),
            const SizedBox(height: AppSpacing.sm),
            _barraBusqueda(),
            _filtrosActivos(),
            _lineaTotales(),
            const SizedBox(height: AppSpacing.md),
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
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: 'Filtros',
          onPressed: _abrirFiltros,
          icon: Badge(
            isLabelVisible: cantidad > 0,
            label: Text('$cantidad'),
            backgroundColor: AppColors.primary,
            child: const Icon(
              Icons.tune,
              color: AppColors.primary,
              size: 28,
            ),
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final a in activos)
            InputChip(
              label: Text(a.texto),
              onDeleted: () => _quitarFiltro(a.clave),
              backgroundColor: AppColors.primaryContainer,
              deleteIconColor: AppColors.primary,
              side: BorderSide.none,
              labelStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (activos.length > 1)
            TextButton(
              onPressed: _quitarTodos,
              child: const Text(
                'Quitar todos',
                style: TextStyle(color: AppColors.primary),
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
      spacing: AppSpacing.sm,
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
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: elegido ? AppColors.primary : AppColors.textPrimary,
        fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: elegido ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) => setState(() => _vista = vista),
    );
  }

  // Total de la lista visible según el chip seleccionado
  Widget _lineaTotales() {
    final t = _totalesDe(_visibles);
    if (_cargandoLista) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            '${t.cantidad} ${t.cantidad == 1 ? 'movimiento' : 'movimientos'}',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Ingresos ${formatearBs(t.ingresos)}',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Gastos ${formatearBs(t.gastos)}',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_cargandoLista) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final movimientos = _visibles;
    if (movimientos.isEmpty) {
      if (_filtros.hayFiltros) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ningún movimiento coincide\ncon la búsqueda o los filtros.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              TextButton(
                onPressed: _quitarTodos,
                child: const Text(
                  'Quitar filtros',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      }

      if (_vista == _VistaMovimientos.recurrentes) {
        return Center(
          child: Text(
            'No tienes gastos recurrentes.\nCrea uno desde Nuevo movimiento.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        );
      }

      if (_vista == _VistaMovimientos.pendientes) {
        return Center(
          child: Text(
            'No tienes movimientos pendientes.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        );
      }

      if (_vista == _VistaMovimientos.pagados) {
        return Center(
          child: Text(
            'No tienes movimientos pagados.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        );
      }

      return Center(
        child: Text(
          'Aún no tienes movimientos.\nCrea el primero con el botón de abajo.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      );
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
        widgets.add(const SizedBox(height: AppSpacing.md));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: widgets,
    );
  }

  Widget _encabezadoGrupo(String titulo, int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
        left: AppSpacing.xs,
      ),
      child: Text(
        '$titulo ($cantidad)',
        style: AppTypography.bodyLargeSemiBold.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _tarjetaMetas() {
    final resumen = _resumenMetas!;
    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderCard,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Metas de ahorro',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _abrirMetas,
                child: const Text(
                  'Ver metas',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Disponible ${resumen.disponibleTexto}',
            style: AppTypography.bodyLargeSemiBold.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Reservado ${resumen.reservadoTexto}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaLimite(ResumenLimite r) {
    final color = r.enAviso ? AppColors.statusWarning : AppColors.primary;
    final borderColor =
        r.enAviso ? AppColors.statusWarning : AppColors.borderStrong;
    final restante = r.restante!;

    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderCard,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastado ${formatearBs(r.gastado)} de ${formatearBs(r.limite!)}',
            style: AppTypography.bodyLargeSemiBold.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.borderSm,
            child: LinearProgressIndicator(
              value: r.proporcion,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            restante >= 0
                ? 'Te quedan ${formatearBs(restante)}'
                : 'Te pasaste por ${formatearBs(-restante)}',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),

          // Lanza aviso por categoria
          for (final cat in _categorias.where((c) => c.excedido)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Atencion: Te pasaste en ${cat.categoria} por ${formatearBs(-cat.restante!)}',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
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
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                  m.concepto,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                m.montoTexto,
                // H4.2: verde para ingresos y rojo para gastos, igual que los totales
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: m.esIngreso ? AppColors.primary : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${m.tipo.texto} · ${m.categoria.texto} · ${m.fechaTexto}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (m.recurrente) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.repeat,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  m.recurrenciaTexto,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: pagado
                      ? AppColors.statusNormalContainer
                      : AppColors.statusWarningContainer,
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  m.estadoTexto,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: pagado
                        ? AppColors.statusNormal
                        : AppColors.statusWarning,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('editar-${m.concepto}'),
                tooltip: 'Editar',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () => _editar(m),
              ),
              IconButton(
                key: ValueKey('eliminar-${m.concepto}'),
                tooltip: 'Eliminar',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
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
                style: const TextStyle(color: AppColors.primary),
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

class _DialogoConfirmarEliminarState
    extends State<_DialogoConfirmarEliminar> {
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
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderModal),
      title: Row(
        children: const [
          Icon(Icons.info_outline, color: AppColors.textPrimary, size: 24),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Eliminar cuenta y datos',
              style: TextStyle(
                color: AppColors.textPrimary,
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
            Text(
              'Esta acción eliminará de forma permanente tu cuenta, todos tus movimientos, metas y presupuestos.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.download_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Te recomendamos descargar una copia de tus datos antes de continuar.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Para confirmar, escribe tu contraseña:',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controlador,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderSm,
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppSizes.touchTargetMin,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderSm,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: AppSizes.touchTargetMin,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderSm,
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
