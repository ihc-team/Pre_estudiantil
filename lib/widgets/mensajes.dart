import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';

// Debajo de cada campo vacío, para que se sepa cuál falta (H9.2)
const String mensajeCampoVacio = 'Completa este campo';

void mostrarMensaje(
  BuildContext context,
  String texto, {
  bool esError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: esError ? AppColors.statusExceeded : Colores.verdeOscuro,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
