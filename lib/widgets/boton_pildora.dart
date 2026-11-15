import 'package:flutter/material.dart';

import 'app_button.dart';

// Adaptador retrocompatible de [BotonPildora] conectado a [AppButton] del sistema de diseño
// Mantiene la API original usada por las pantallas heredadas para evitar roturas
// mientras delega toda la renderizacion a los tokens oficiales
class BotonPildora extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool esRelleno;
  final VoidCallback alPresionar;

  const BotonPildora({
    super.key,
    required this.texto,
    required this.icono,
    required this.alPresionar,
    this.esRelleno = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: texto,
      leadingIcon: icono,
      onPressed: alPresionar,
      variant: esRelleno ? AppButtonVariant.primary : AppButtonVariant.secondary,
      size: AppButtonSize.large,
    );
  }
}
