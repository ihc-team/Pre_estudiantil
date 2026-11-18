import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'tema/app_tokens.dart';

// Clase retrocompatible que mapea a los nuevos tokens oficiales con [AppColors]
// Se permite migrar pantallas progresivamente sin romper el codigo que ya existe
class Colores {
  static const Color verdeOscuro = AppColors.primary;
  static const Color verdeClaro = AppColors.primaryContainer;
  static const Color azulOscuro = AppColors.textPrimary;
  static const Color grisAzulado = AppColors.textSecondary;
  static const Color fondo = AppColors.background;
  static const Color rojo = AppColors.statusExceeded;
  static const Color aviso = AppColors.statusWarning;
}

class Servidor {
  // La URL se configura en el .env de la raíz (API_BASE_URL)
  static String get urlBase =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';
}
