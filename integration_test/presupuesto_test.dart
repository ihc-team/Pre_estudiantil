import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ihcpre_estudiantil2/main.dart' as app;

const String _correo = 'prueba@correo.com';
const String _contrasena = '123456';

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

double _leerGastos(WidgetTester tester) {
  final finder = find.textContaining('Gastos Bs ');
  expect(finder, findsOneWidget);
  final texto = tester.widget<Text>(finder).data!;
  final numero = texto
      .replaceFirst('Gastos Bs ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.parse(numero);
}

Future<double> _esperarGastos(WidgetTester tester) async {
  final fin = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.textContaining('Gastos Bs ').evaluate().isNotEmpty) {
      return _leerGastos(tester);
    }
  }
  fail('No se cargó la línea de totales.');
}

Future<double> _esperarGastosMayores(
  WidgetTester tester,
  double anterior,
) async {
  final fin = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.textContaining('Gastos Bs ').evaluate().isNotEmpty) {
      final actual = _leerGastos(tester);
      if (actual > anterior) return actual;
    }
  }
  fail('El total de gastos no cambió después de registrar el gasto.');
}

Future<void> _asegurarSesion(WidgetTester tester) async {
  await _esperarAlguno(tester, ['Iniciar sesión', 'Mis movimientos', 'Entrar']);

  if (find.text('Mis movimientos').evaluate().isNotEmpty) return;

  if (find.text('Entrar').evaluate().isEmpty) {
    await tester.tap(find.text('Iniciar sesión').last);
    await _esperarTexto(tester, 'Entrar');
  }

  final correo = _campo('Correo');
  final contrasena = _campo('Contraseña');
  expect(correo, findsOneWidget);
  expect(contrasena, findsOneWidget);
  await tester.enterText(correo, _correo);
  await tester.enterText(contrasena, _contrasena);

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await _esperarTexto(tester, 'Mis movimientos');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registrar un gasto cambia el total', (tester) async {
    app.main();
    await _asegurarSesion(tester);

    final gastosAntes = await _esperarGastos(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await _esperarTexto(tester, 'Categoría');

    final chipComida = find.widgetWithText(ChoiceChip, 'Comida');
    expect(chipComida, findsOneWidget);
    await tester.ensureVisible(chipComida);
    await tester.tap(chipComida);
    await tester.pump();

    final concepto = 'Gasto E2E ${DateTime.now().millisecondsSinceEpoch}';
    const monto = 12;
    await tester.enterText(_campo('Concepto'), concepto);
    await tester.enterText(_campo('Monto (Bs)'), monto.toStringAsFixed(2));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));

    await _esperarSinTexto(tester, 'Categoría');
    await _esperarTexto(tester, 'Mis movimientos');
    final gastosDespues = await _esperarGastosMayores(tester, gastosAntes);

    expect(gastosDespues, greaterThan(gastosAntes));
    expect(gastosDespues - gastosAntes, closeTo(monto, 0.01));
    expect(find.text(concepto), findsOneWidget);
    await Future.delayed(const Duration(minutes: 10));
  });
}
