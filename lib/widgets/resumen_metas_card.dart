import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../modelos/meta_ahorro.dart';

class ResumenMetasCard extends StatelessWidget {
  final ResumenMetas resumen;

  const ResumenMetasCard({super.key, required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colores.verdeClaro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.azulOscuro,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Total ${resumen.totalTexto}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colores.azulOscuro,
                ),
              ),
              Text(
                'Reservado ${resumen.reservadoTexto}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colores.aviso,
                ),
              ),
              Text(
                'Disponible ${resumen.disponibleTexto}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colores.verdeOscuro,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
