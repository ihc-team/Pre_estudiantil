import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../servicios/analitica.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_cuenta.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/mensajes.dart';

class PantallaMisDatos extends StatefulWidget {
  const PantallaMisDatos({super.key});

  @override
  State<PantallaMisDatos> createState() => _PantallaMisDatosState();
}

class _PantallaMisDatosState extends State<PantallaMisDatos> {
  bool _cargando = true;
  bool _descargando = false;
  Map<String, dynamic>? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await ServicioCuenta.exportar();
      if (!mounted) return;
      setState(() {
        _datos = datos;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus datos';
        _cargando = false;
      });
    }
  }

  Future<void> _descargarJson() async {
    if (_datos == null) return;

    setState(() => _descargando = true);
    try {
      final jsonTexto = const JsonEncoder.withIndent('  ').convert(_datos);

      // Copia el JSON completo al portapapeles para mayor compatibilidad
      await Clipboard.setData(ClipboardData(text: jsonTexto));

      // Analitica, se registra la descarga exitosa sin datos personales
      await AnaliticaServicio.track('datos_descargados', {'formato': 'json'});

      if (!mounted) return;
      mostrarMensaje(
        context,
        'Tus datos en formato JSON fueron copiados al portapapeles listos para guardar o compartir.',
      );
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo generar la descarga', esError: true);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = (_datos?['movimientos'] as List?) ?? [];
    final metas = (_datos?['metas'] as List?) ?? [];
    final presupuestos = (_datos?['presupuestosCategorias'] as List?) ?? [];
    final usuario = _datos?['usuario'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis datos y cuenta'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colores.azulOscuro,
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Colores.verdeOscuro),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colores.rojo,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colores.grisAzulado),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _cargarDatos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colores.verdeOscuro,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Transparencia y control de tus datos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colores.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Aquí puedes revisar toda la informacion registrada en tu cuenta y descargar una copia en formato JSON en cualquier momento.',
                    style: TextStyle(
                      color: Colores.grisAzulado,
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tarjeta de perfil
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colores.verdeClaro),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario['nombre']?.toString() ?? 'Usuario',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colores.azulOscuro,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          usuario['correo']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colores.grisAzulado,
                            fontSize: 14,
                          ),
                        ),
                        if (usuario['miembroDesde'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Miembro desde: ${usuario['miembroDesde']}',
                            style: const TextStyle(
                              color: Colores.grisAzulado,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resumen de registros almacenados
                  const Text(
                    'Registros vinculados a tu cuenta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _tarjetaResumen(
                    titulo: 'Movimientos financieros',
                    subtitulo: 'Gastos e ingresos registrados',
                    cantidad: movimientos.length,
                    icono: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: 8),
                  _tarjetaResumen(
                    titulo: 'Metas de ahorro',
                    subtitulo: 'Objetivos y fondos reservados',
                    cantidad: metas.length,
                    icono: Icons.flag_outlined,
                  ),
                  const SizedBox(height: 8),
                  _tarjetaResumen(
                    titulo: 'Presupuestos por categoría',
                    subtitulo: 'Límites mensuales asignados',
                    cantidad: presupuestos.length,
                    icono: Icons.tune_outlined,
                  ),
                  const SizedBox(height: 24),

                  // Boton para descargar datos
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _descargando ? null : _descargarJson,
                      icon: _descargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: const Text(
                        'Descargar mis datos (JSON)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colores.verdeOscuro,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Zona de salida honesta, que es la eliminacion
                  const Divider(color: Colores.verdeClaro),
                  const SizedBox(height: 16),
                  const Text(
                    'Zona de cierre de cuenta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Si decides marcharte, respetamos tu decisión. Puedes eliminar tu cuenta de forma permanente y llevarte tus datos.',
                    style: TextStyle(
                      color: Colores.grisAzulado,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, 'solicitar_eliminar');
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colores.azulOscuro,
                    ),
                    label: const Text(
                      'Eliminar mi cuenta y datos',
                      style: TextStyle(
                        color: Colores.azulOscuro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colores.grisAzulado),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tarjetaResumen({
    required String titulo,
    required String subtitulo,
    required int cantidad,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colores.verdeClaro),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colores.verdeOscuro, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colores.azulOscuro,
                  ),
                ),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.grisAzulado,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colores.verdeClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colores.verdeOscuro,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
