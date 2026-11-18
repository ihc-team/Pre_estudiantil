import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';

class CampoTexto extends StatefulWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final bool esContrasena;
  final bool habilitado;
  final bool soloLectura;
  final VoidCallback? alTocar;
  final TextInputType tipoTeclado;
  // Mensaje que se muestra debajo del campo (null = sin error)
  final String? error;
  final ValueChanged<String>? alCambiar;
  final String? pista;
  final FocusNode? nodoFoco;

  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.esContrasena = false,
    this.habilitado = true,
    this.soloLectura = false,
    this.alTocar,
    this.tipoTeclado = TextInputType.text,
    this.error,
    this.alCambiar,
    this.pista,
    this.nodoFoco,
  });

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;

  OutlineInputBorder _borde(Color color, [double grosor = 1.5]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: grosor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controlador,
      focusNode: widget.nodoFoco,
      enabled: widget.habilitado,
      readOnly: widget.soloLectura,
      onTap: widget.alTocar,
      onChanged: widget.alCambiar,
      keyboardType: widget.tipoTeclado,
      obscureText: widget.esContrasena && _oculto,
      obscuringCharacter: '✏',
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        hintText: widget.pista,
        errorText: widget.error,
        errorMaxLines: 3,
        labelStyle: const TextStyle(color: Colores.grisAzulado),
        floatingLabelStyle: const TextStyle(color: Colores.verdeOscuro),
        prefixIcon: Icon(widget.icono, color: Colores.verdeOscuro),
        suffixIcon: widget.esContrasena
            ? IconButton(
                icon: Icon(
                  _oculto
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colores.grisAzulado,
                ),
                onPressed: () => setState(() => _oculto = !_oculto),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: _borde(Colores.verdeClaro),
        enabledBorder: _borde(Colores.verdeClaro),
        focusedBorder: _borde(Colores.verdeOscuro, 2),
        errorBorder: _borde(Colores.rojo),
        focusedErrorBorder: _borde(Colores.rojo, 2),
      ),
    );
  }
}
