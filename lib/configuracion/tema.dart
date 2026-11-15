import 'package:flutter/material.dart';

import 'tema/app_tema.dart';

/// Adaptador retrocompatible de TemaApp para el arranque de la app.
class TemaApp {
  static ThemeData get temaClaro => AppTheme.lightTheme;
}
