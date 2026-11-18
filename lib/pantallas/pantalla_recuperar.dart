import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../servicios/servicio_acceso.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';

class PantallaRecuperar extends StatefulWidget {
  const PantallaRecuperar({super.key});

  @override
  State<PantallaRecuperar> createState() => _PantallaRecuperarState();
}

class _PantallaRecuperarState extends State<PantallaRecuperar> {
  final _correo = TextEditingController();
  final _codigoEscrito = TextEditingController();
  final _nuevaContrasena = TextEditingController();

  // Si es null estamos en el paso 1; si tiene valor, en el paso 2
  String? _codigoRecibido;
  bool _cargando = false;
  String? _errorCorreo;
  String? _errorCodigo;
  String? _errorNueva;

  @override
  void dispose() {
    _correo.dispose();
    _codigoEscrito.dispose();
    _nuevaContrasena.dispose();
    super.dispose();
  }

  // Paso 1: pedir el código
  Future<void> _pedirCodigo() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty) {
      setState(() => _errorCorreo = 'Escribe tu correo');
      return;
    }

    setState(() => _cargando = true);
    try {
      final codigo = await ServicioAcceso.pedirCodigo(correo);
      if (!mounted) return;
      setState(() => _codigoRecibido = codigo);
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // H3.2: vuelve al paso 1 para corregir el correo, sin borrar lo escrito
  void _cambiarCorreo() {
    setState(() {
      _codigoRecibido = null;
      _errorCorreo = null;
    });
  }

  // Paso 2: cambiar la contraseña con el código
  Future<void> _cambiarContrasena() async {
    final codigo = _codigoEscrito.text.trim();
    final nueva = _nuevaContrasena.text;

    setState(() {
      _errorCodigo = codigo.isEmpty ? mensajeCampoVacio : null;
      _errorNueva = nueva.isEmpty
          ? mensajeCampoVacio
          : (nueva.length < 6
                ? 'La contraseña debe tener mínimo 6 caracteres'
                : null);
    });
    if (_errorCodigo != null || _errorNueva != null) return;

    setState(() => _cargando = true);
    try {
      await ServicioAcceso.cambiarContrasena(
        _correo.text.trim(),
        codigo,
        nueva,
      );
      if (!mounted) return;
      mostrarMensaje(context, 'Contraseña actualizada. Inicia sesión');
      Navigator.pushNamedAndRemoveUntil(
        context,
        Rutas.login,
        ModalRoute.withName(Rutas.inicio),
      );
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enPaso2 = _codigoRecibido != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        foregroundColor: Colores.azulOscuro,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Recuperar contraseña',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colores.azulOscuro,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                enPaso2
                    ? 'Escribe el código y tu nueva contraseña.'
                    : 'Te daremos un código de 6 dígitos.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colores.grisAzulado,
                ),
              ),
              const SizedBox(height: 32),
              CampoTexto(
                controlador: _correo,
                etiqueta: 'Correo',
                icono: Icons.mail_outline,
                tipoTeclado: TextInputType.emailAddress,
                habilitado: !enPaso2,
                error: _errorCorreo,
                alCambiar: (_) {
                  if (_errorCorreo != null) setState(() => _errorCorreo = null);
                },
              ),
              const SizedBox(height: 16),
              // H3.2: si el correo estaba mal escrito, se corrige sin salir
              if (enPaso2)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _cambiarCorreo,
                    child: const Text(
                      'Cambiar correo',
                      style: TextStyle(color: Colores.verdeOscuro),
                    ),
                  ),
                ),

              if (enPaso2) ...[
                // No se envía correo real: mostramos el código en pantalla
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colores.verdeClaro,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Tu código de recuperación',
                        style: TextStyle(color: Colores.azulOscuro),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _codigoRecibido!,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Colores.verdeOscuro,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Válido por 15 minutos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colores.grisAzulado,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _codigoEscrito,
                  etiqueta: 'Código',
                  icono: Icons.pin_outlined,
                  tipoTeclado: TextInputType.number,
                  error: _errorCodigo,
                  alCambiar: (_) {
                    if (_errorCodigo != null)
                      setState(() => _errorCodigo = null);
                  },
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _nuevaContrasena,
                  etiqueta: 'Nueva contraseña',
                  icono: Icons.lock_outline,
                  esContrasena: true,
                  error: _errorNueva,
                  alCambiar: (_) {
                    if (_errorNueva != null) setState(() => _errorNueva = null);
                  },
                ),
              ],

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
                        texto: enPaso2
                            ? 'Cambiar contraseña'
                            : 'Obtener código',
                        icono: enPaso2 ? Icons.check : Icons.mail_outline,
                        alPresionar: enPaso2
                            ? _cambiarContrasena
                            : _pedirCodigo,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
