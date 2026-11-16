import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../modelos/correo.dart';
import '../servicios/servicio_acceso.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _cargando = false;
  String? _errorNombre;
  String? _errorCorreo;
  String? _errorContrasena;
  String? _errorConfirmacion;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final nombre = _nombre.text.trim();
    final correo = _correo.text.trim();
    final contrasena = _contrasena.text;

    // Cada error va debajo de su campo, todos a la vez
    setState(() {
      _errorNombre = nombre.isEmpty ? mensajeCampoVacio : null;
      _errorCorreo = correo.isEmpty ? mensajeCampoVacio : validarCorreo(correo);
      _errorContrasena = contrasena.isEmpty
          ? mensajeCampoVacio
          : (contrasena.length < 6
                ? 'La contraseña debe tener mínimo 6 caracteres'
                : null);
      _errorConfirmacion =
          _errorContrasena == null && contrasena != _confirmacion.text
          ? 'Las contraseñas no coinciden'
          : null;
    });
    if (_errorNombre != null ||
        _errorCorreo != null ||
        _errorContrasena != null ||
        _errorConfirmacion != null) {
      return;
    }

    setState(() => _cargando = true);
    try {
      await ServicioAcceso.registrar(nombre, correo, contrasena);
      if (!mounted) return;
      mostrarMensaje(context, 'Cuenta creada. Ahora inicia sesión');
      // Volvemos al login dejando solo la pantalla de inicio detrás
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
    return Scaffold(
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
              const Text(
                'Crear cuenta',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colores.azulOscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tus datos solo se usarán para gestionar tu presupuesto personal y no se compartirán con terceros.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colores.grisAzulado,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              CampoTexto(
                controlador: _nombre,
                etiqueta: 'Nombre',
                icono: Icons.person_outline,
                error: _errorNombre,
                alCambiar: (_) {
                  if (_errorNombre != null) setState(() => _errorNombre = null);
                },
              ),
              const SizedBox(height: 16),
              CampoTexto(
                controlador: _correo,
                etiqueta: 'Correo',
                icono: Icons.mail_outline,
                tipoTeclado: TextInputType.emailAddress,
                error: _errorCorreo,
                alCambiar: (_) {
                  if (_errorCorreo != null) setState(() => _errorCorreo = null);
                },
              ),
              const SizedBox(height: 16),
              CampoTexto(
                controlador: _contrasena,
                etiqueta: 'Contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
                error: _errorContrasena,
                alCambiar: (_) {
                  if (_errorContrasena != null)
                    setState(() => _errorContrasena = null);
                },
              ),
              const SizedBox(height: 16),
              CampoTexto(
                controlador: _confirmacion,
                etiqueta: 'Repetir contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
                error: _errorConfirmacion,
                alCambiar: (_) {
                  if (_errorConfirmacion != null)
                    setState(() => _errorConfirmacion = null);
                },
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
                        texto: 'Registrarse',
                        icono: Icons.person_add_alt_outlined,
                        alPresionar: _registrar,
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
