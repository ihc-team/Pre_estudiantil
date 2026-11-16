import 'package:flutter/material.dart';

import '../pantallas/pantalla_analitica.dart';
import '../pantallas/pantalla_arranque.dart';
import '../pantallas/pantalla_historial.dart';
import '../pantallas/pantalla_inicio.dart';
import '../pantallas/pantalla_limite.dart';
import '../pantallas/pantalla_login.dart';
import '../pantallas/pantalla_metas.dart';
import '../pantallas/pantalla_mis_datos.dart';
import '../pantallas/pantalla_movimientos.dart';
import '../pantallas/pantalla_nuevo_movimiento.dart';
import '../pantallas/pantalla_recuperar.dart';
import '../pantallas/pantalla_registro.dart';

class Rutas {
  static const String arranque = '/';
  static const String inicio = '/inicio';
  static const String login = '/login';
  static const String registro = '/registro';
  static const String recuperar = '/recuperar';
  static const String movimientos = '/movimientos';
  static const String nuevoMovimiento = '/nuevo-movimiento';
  static const String limite = '/limite';
  static const String historial = '/historial';
  static const String metas = '/metas';
  static const String analitica = '/analitica';
  static const String misDatos = '/mis-datos';

  static final Map<String, WidgetBuilder> mapa = {
    arranque: (context) => const PantallaArranque(),
    inicio: (context) => const PantallaInicio(),
    login: (context) => const PantallaLogin(),
    registro: (context) => const PantallaRegistro(),
    recuperar: (context) => const PantallaRecuperar(),
    movimientos: (context) => const PantallaMovimientos(),
    nuevoMovimiento: (context) => const PantallaNuevoMovimiento(),
    limite: (context) => const PantallaLimite(),
    historial: (context) => const PantallaHistorial(),
    metas: (context) => const PantallaMetas(),
    analitica: (context) => const PantallaAnalitica(),
    misDatos: (context) => const PantallaMisDatos(),
  };
}
