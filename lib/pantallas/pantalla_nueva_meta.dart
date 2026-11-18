import 'package:flutter/material.dart';

import '../configuracion/rutas.dart';
import '../configuracion/tema/app_tokens.dart';
import '../modelos/movimiento.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_metas.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';
import '../servicios/analitica.dart';

class PantallaNuevaMeta extends StatefulWidget {
  const PantallaNuevaMeta({super.key});

  @override
  State<PantallaNuevaMeta> createState() => _PantallaNuevaMetaState();
}

class _PantallaNuevaMetaState extends State<PantallaNuevaMeta> {
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  final _fechaTexto = TextEditingController();
  late DateTime _fecha;
  bool _cargando = false;
  String? _errorNombre;
  String? _errorMonto;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _fecha = DateTime(hoy.year, hoy.month + 3, hoy.day);
    _fechaTexto.text = Movimiento.formatearFecha(_fecha);
    // Analitica, usuario inicia creacion de meta de ahorro
    AnaliticaServicio.track('meta_creacion_iniciada', {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    _fechaTexto.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _fechaTexto.text = Movimiento.formatearFecha(elegida);
      });
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', '.'));

    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe el nombre de la meta' : null;
      _errorMonto = _monto.text.trim().isEmpty
          ? 'Escribe el monto objetivo'
          : (monto == null || monto <= 0
                ? 'El monto debe ser mayor a 0'
                : null);
    });
    if (_errorNombre != null || _errorMonto != null) return;

    setState(() => _cargando = true);
    try {
      await ServicioMetas.crear(nombre, monto!, _fecha);
      // Analitica, meta guardada con exito tras respuesta de base de datos
      AnaliticaServicio.track('meta_guardada', {});
      if (!mounted) return;
      mostrarMensaje(context, 'Meta creada');
      Navigator.pop(context, true);
    } on SesionExpirada {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Nueva meta',
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Define cuánto quieres ahorrar y para cuándo.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              CampoTexto(
                controlador: _nombre,
                etiqueta: 'Nombre de la meta',
                icono: Icons.flag_outlined,
                error: _errorNombre,
                alCambiar: (_) {
                  if (_errorNombre != null) {
                    setState(() => _errorNombre = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              CampoTexto(
                controlador: _monto,
                etiqueta: 'Monto objetivo (Bs)',
                icono: Icons.savings_outlined,
                tipoTeclado: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                error: _errorMonto,
                alCambiar: (_) {
                  if (_errorMonto != null) {
                    setState(() => _errorMonto = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              CampoTexto(
                controlador: _fechaTexto,
                etiqueta: 'Fecha objetivo',
                icono: Icons.calendar_today_outlined,
                soloLectura: true,
                alTocar: _elegirFecha,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : BotonPildora(
                        texto: 'Guardar meta',
                        icono: Icons.check,
                        alPresionar: _guardar,
                      ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
