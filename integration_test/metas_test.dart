import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ihcpre_estudiantil2/configuracion/constantes.dart';
import 'package:ihcpre_estudiantil2/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

Future<void> _esperarTexto(
  WidgetTester tester,
  String texto, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(texto).evaluate().isNotEmpty) return;
  }
  fail('No apareció "$texto" en la pantalla.');
}

Future<void> _esperarSinTexto(
  WidgetTester tester,
  String texto, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(texto).evaluate().isEmpty) return;
  }
  fail('La pantalla con "$texto" no se cerró.');
}

Future<void> _esperarAlguno(
  WidgetTester tester,
  List<String> textos, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find
        .text('No se pudo conectar con el servidor')
        .evaluate()
        .isNotEmpty) {
      fail(
        'El backend no responde. Inicia el servidor en http://localhost:3000.',
      );
    }
    for (final texto in textos) {
      if (find.text(texto).evaluate().isNotEmpty) return;
    }
  }
  fail('No apareció ninguno de: ${textos.join(', ')}.');
}

Future<http.Response> _post(
  String ruta,
  Map<String, dynamic> body, {
  String? token,
}) {
  return http.post(
    Uri.parse('${Servidor.urlBase}$ruta'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
}

Future<({String correo, String contrasena})> _prepararUsuario({
  bool conMovimientos = true,
}) async {
  final correo =
      'metas-e2e-${DateTime.now().millisecondsSinceEpoch}@correo.com';
  const contrasena = '123456';

  final registro = await _post('/registro', {
    'nombre': 'Usuario Metas E2E',
    'correo': correo,
    'contrasena': contrasena,
  });
  expect(registro.statusCode, 201);

  if (!conMovimientos) {
    return (correo: correo, contrasena: contrasena);
  }

  final login = await _post('/login', {
    'correo': correo,
    'contrasena': contrasena,
  });
  expect(login.statusCode, 200);
  final token =
      (jsonDecode(login.body) as Map<String, dynamic>)['token'] as String;
  final fecha = DateTime.now().toIso8601String().substring(0, 10);

  final ingreso = await _post('/movimientos', {
    'concepto': 'Ingreso E2E metas',
    'monto': 1000,
    'fecha': fecha,
    'tipo': 'ingreso',
    'categoria': 'otros',
  }, token: token);
  expect(ingreso.statusCode, 201);

  final gasto = await _post('/movimientos', {
    'concepto': 'Gasto E2E metas',
    'monto': 400,
    'fecha': fecha,
    'tipo': 'gasto',
    'categoria': 'comida',
  }, token: token);
  expect(gasto.statusCode, 201);

  return (correo: correo, contrasena: contrasena);
}

Future<void> _cerrarTeclado(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _esperarSinCargando(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
  fail('La pantalla no termin� de cargar.');
}

Future<void> _esperarSinSnackBar(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(SnackBar).evaluate().isEmpty) return;
  }
}

Future<void> _iniciarSesion(
  WidgetTester tester,
  String correo,
  String contrasena,
) async {
  await _esperarAlguno(tester, ['Iniciar sesión', 'Mis movimientos', 'Entrar']);

  if (find.text('Mis movimientos').evaluate().isNotEmpty) return;

  if (find.text('Entrar').evaluate().isEmpty) {
    await tester.tap(find.text('Iniciar sesión').last);
    await _esperarTexto(tester, 'Entrar');
  }

  await tester.enterText(_campo('Correo'), correo);
  await tester.enterText(_campo('Contraseña'), contrasena);
  await _cerrarTeclado(tester);
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await _esperarTexto(tester, 'Mis movimientos');
}

Future<void> _irAMetas(WidgetTester tester) async {
  await _esperarTexto(tester, 'Mis movimientos');
  await _esperarTexto(tester, 'Ver metas');
  await tester.ensureVisible(find.text('Ver metas'));
  await tester.tap(find.text('Ver metas'));
  await _esperarTexto(tester, 'Saldos');
}

Future<void> _abrirNuevaMeta(WidgetTester tester) async {
  final boton = find.text('Nueva meta');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
}

Future<void> _crearMeta(
  WidgetTester tester,
  String nombre,
  double monto,
) async {
  await _abrirNuevaMeta(tester);
  await _esperarTexto(tester, 'Nombre de la meta');
  await tester.enterText(_campo('Nombre de la meta'), nombre);
  await tester.enterText(
    _campo('Monto objetivo (Bs)'),
    monto.toStringAsFixed(2),
  );
  await _cerrarTeclado(tester);
  await tester.ensureVisible(find.text('Guardar meta'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.tap(find.text('Guardar meta'));
  await _esperarSinTexto(tester, 'Guardar meta');
  await _esperarSinCargando(tester);
  await _esperarSinSnackBar(tester);
}

Future<void> _abrirMeta(WidgetTester tester, String nombre) async {
  final finder = find.text(nombre);
  if (finder.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(finder, 200);
    } catch (_) {
      await tester.scrollUntilVisible(finder, -200);
    }
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _esperarTexto(tester, 'Asignar');
}

Future<void> _confirmarMonto(WidgetTester tester, double monto) async {
  await _esperarTexto(tester, 'Monto (Bs)');
  await tester.enterText(_campo('Monto (Bs)'), monto.toStringAsFixed(2));
  await _cerrarTeclado(tester);
  await tester.ensureVisible(find.text('Confirmar'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.tap(find.text('Confirmar'));
  await _esperarSinTexto(tester, 'Confirmar');
}

Future<void> _asignar(WidgetTester tester, double monto) async {
  await tester.tap(find.text('Asignar'));
  await _confirmarMonto(tester, monto);
  await _esperarTexto(tester, 'Asignar');
}

Future<void> _retirar(WidgetTester tester, double monto) async {
  await tester.tap(find.text('Retirar'));
  await _confirmarMonto(tester, monto);
  await _esperarTexto(tester, 'Retirar');
}

Future<void> _transferir(WidgetTester tester, double monto) async {
  await tester.tap(find.text('Transferir'));
  await _confirmarMonto(tester, monto);
  await _esperarTexto(tester, 'Transferir');
}

Future<void> _intentarAsignarSinFondos(
  WidgetTester tester,
  double monto,
) async {
  await tester.tap(find.text('Asignar'));
  await _confirmarMonto(tester, monto);
  await _esperarTexto(tester, 'No hay fondos disponibles suficientes');
}

Future<void> _volver(WidgetTester tester) async {
  final boton = find.byType(BackButton);
  if (boton.evaluate().isNotEmpty) {
    await tester.tap(boton.first);
  } else {
    await tester.tap(find.byIcon(Icons.arrow_back).first);
  }
  await _esperarTexto(tester, 'Metas de ahorro');
  await _esperarSinCargando(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load();
  });

  testWidgets('recorrido completo de metas con fondos reservados', (
    tester,
  ) async {
    final usuario = await _prepararUsuario();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    await app.main();
    await _iniciarSesion(tester, usuario.correo, usuario.contrasena);
    await _irAMetas(tester);

    await _crearMeta(tester, 'Meta A', 500);
    await _crearMeta(tester, 'Meta B', 300);

    await _abrirMeta(tester, 'Meta A');
    await _asignar(tester, 200);
    await _esperarTexto(tester, 'Disponible Bs 400,00');
    await _esperarTexto(tester, 'Reservado Bs 200,00');
    await _volver(tester);

    await _abrirMeta(tester, 'Meta B');
    await _asignar(tester, 100);
    await _esperarTexto(tester, 'Disponible Bs 300,00');
    await _esperarTexto(tester, 'Reservado Bs 300,00');
    await _volver(tester);

    await _abrirMeta(tester, 'Meta A');
    await _transferir(tester, 50);
    await _esperarTexto(tester, 'Reservado: Bs 150,00');
    await tester.scrollUntilVisible(find.text('Transferencia enviada'), 200);
    expect(find.text('Transferencia enviada'), findsOneWidget);
    await _volver(tester);

    await _abrirMeta(tester, 'Meta B');
    await _retirar(tester, 100);
    await _esperarTexto(tester, 'Disponible Bs 400,00');
    await _esperarTexto(tester, 'Reservado Bs 200,00');
    await _esperarTexto(tester, 'Reservado: Bs 50,00');
    await tester.scrollUntilVisible(find.text('Retiro'), 200);
    expect(find.text('Retiro'), findsOneWidget);
    await _volver(tester);

    await _abrirMeta(tester, 'Meta A');
    await _intentarAsignarSinFondos(tester, 500);
    await _esperarTexto(tester, 'Disponible Bs 400,00');
    await _esperarTexto(tester, 'Reservado Bs 200,00');
    await _esperarTexto(tester, 'Reservado: Bs 150,00');
    await _volver(tester);

    await _esperarTexto(tester, 'Total Bs 600,00');
    await _esperarTexto(tester, 'Reservado Bs 200,00');
    await _esperarTexto(tester, 'Disponible Bs 400,00');

    final botonVolver = find.byType(BackButton);
    if (botonVolver.evaluate().isNotEmpty) {
      await tester.tap(botonVolver.first);
    } else {
      await tester.tap(find.byIcon(Icons.arrow_back).first);
    }
    await _esperarTexto(tester, 'Mis movimientos');
    await _irAMetas(tester);
    await _esperarTexto(tester, 'Disponible Bs 400,00');
    await _esperarTexto(tester, 'Reservado Bs 200,00');
  });

}
