import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/configuracion/tema.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_login.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_nueva_meta.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_recuperar.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_registro.dart';

Widget _app(Widget screen) => MaterialApp(
  theme: TemaApp.temaClaro,
  home: screen,
);

void main() {
  testWidgets('Login muestra errores con campos vacíos', (tester) async {
    await tester.pumpWidget(_app(const PantallaLogin()));
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Completa este campo'), findsNWidgets(2));
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Registro muestra errores con campos vacíos', (tester) async {
    await tester.pumpWidget(_app(const PantallaRegistro()));
    await tester.tap(find.text('Registrarse'));
    await tester.pump();

    expect(find.text('Completa este campo'), findsWidgets);
    expect(find.text('Nombre'), findsOneWidget);
  });

  testWidgets('Recuperar muestra error sin correo', (tester) async {
    await tester.pumpWidget(_app(const PantallaRecuperar()));
    await tester.tap(find.text('Obtener código'));
    await tester.pump();

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
  });

  testWidgets('Nueva meta muestra errores con campos vacíos', (tester) async {
    await tester.pumpWidget(_app(const PantallaNuevaMeta()));
    await tester.tap(find.text('Guardar meta'));
    await tester.pump();

    expect(find.text('Escribe el nombre de la meta'), findsOneWidget);
    expect(find.text('Escribe el monto objetivo'), findsOneWidget);
  });
}
