import 'package:flutter/material.dart';

import 'tema/app_tema.dart';

// Adaptador retrocompatible para el arranque de la app
class TemaApp {
  static ThemeData get temaClaro => AppTheme.lightTheme;
}
