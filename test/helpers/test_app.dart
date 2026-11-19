import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/configuracion/rutas.dart';
import 'package:ihcpre_estudiantil2/configuracion/tema.dart';

Widget appPrueba(Widget home) => MaterialApp(
  key: UniqueKey(),
  theme: TemaApp.temaClaro,
  home: home,
  onGenerateRoute: (settings) {
    final constructor = Rutas.mapa[settings.name];
    if (constructor == null) return null;
    return MaterialPageRoute(settings: settings, builder: constructor);
  },
);

void pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
