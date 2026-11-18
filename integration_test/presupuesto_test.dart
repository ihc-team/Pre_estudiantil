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

Future<void> _cerrarTeclado(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _esperarSinSnackBar(WidgetTester tester) async {
  final fin = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(SnackBar).evaluate().isEmpty) return;
  }
}

Future<void> _confirmarAvisoLimite(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.text('Confirmar gasto').evaluate().isNotEmpty) {
    await tester.tap(find.text('Confirmar gasto'));
    await tester.pumpAndSettle();
  }
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

  if (find.text('Mis movimientos').evaluate().isNotEmpty) {
    await _esperarSinSnackBar(tester);
    return;
  }

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

  await _cerrarTeclado(tester);
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await _esperarTexto(tester, 'Mis movimientos');
  await _esperarSinSnackBar(tester);
}

Future<void> _volverAtras(WidgetTester tester) async {
  final botonAtras = find.byType(BackButton);
  if (botonAtras.evaluate().isNotEmpty) {
    await tester.tap(botonAtras.first);
  } else {
    final iconoAtras = find.byIcon(Icons.arrow_back);
    await tester.tap(iconoAtras.first);
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _abrirPantallaLimite(WidgetTester tester) async {
  final botonLimite = find.widgetWithText(TextButton, 'Límite');
  expect(botonLimite, findsOneWidget);
  await tester.tap(botonLimite);
  await _esperarTexto(tester, 'Presupuesto por categorías');
  await _esperarTexto(tester, 'Comida');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registrar un gasto cambia el total', (tester) async {
    await app.main();
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
    const monto = 12.0;
    await tester.enterText(_campo('Concepto'), concepto);
    await tester.enterText(_campo('Monto (Bs)'), monto.toStringAsFixed(2));

    await _cerrarTeclado(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await _confirmarAvisoLimite(tester);

    await _esperarSinTexto(tester, 'Categor�a');
    await _esperarTexto(tester, 'Mis movimientos');
    final gastosDespues = await _esperarGastosMayores(tester, gastosAntes);

    expect(gastosDespues, greaterThan(gastosAntes));
    expect(gastosDespues - gastosAntes, closeTo(monto, 0.01));
  });

  // tarea 7
  testWidgets('un ingreso no altera el consumo del presupuesto por categoría', (
    tester,
  ) async {
    await app.main();
    await _asegurarSesion(tester);

    await _abrirPantallaLimite(tester);

    final tarjetaComida = find.text('Comida');
    expect(tarjetaComida, findsWidgets);
    await tester.ensureVisible(tarjetaComida.first);
    await tester.tap(tarjetaComida.first);
    await _esperarTexto(tester, 'Presupuesto (Bs)');

    final campoPresupuesto = _campo('Presupuesto (Bs)');
    await tester.enterText(campoPresupuesto, '300.00');
    await _cerrarTeclado(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await _esperarSinTexto(tester, 'Presupuesto (Bs)');
    await _esperarTexto(tester, 'Presupuesto por categorías');

    await _volverAtras(tester);
    await _esperarTexto(tester, 'Mis movimientos');
    final gastosAntesDeIngreso = await _esperarGastos(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await _esperarTexto(tester, 'Categoría');

    final chipIngreso = find.widgetWithText(ChoiceChip, 'Ingreso');
    await tester.ensureVisible(chipIngreso);
    await tester.tap(chipIngreso);
    await tester.pump();

    final chipComida = find.widgetWithText(ChoiceChip, 'Comida');
    await tester.ensureVisible(chipComida);
    await tester.tap(chipComida);
    await tester.pump();

    final conceptoIngreso =
        'Ingreso Beca E2E ${DateTime.now().millisecondsSinceEpoch}';
    const montoIngreso = 100.0;
    await tester.enterText(_campo('Concepto'), conceptoIngreso);
    await tester.enterText(
      _campo('Monto (Bs)'),
      montoIngreso.toStringAsFixed(2),
    );

    await _cerrarTeclado(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));

    await _esperarSinTexto(tester, 'Categoría');
    await _esperarTexto(tester, 'Mis movimientos');
    await _esperarSinSnackBar(tester);

    final gastosDespuesDeIngreso = await _esperarGastos(tester);
    expect(gastosDespuesDeIngreso, equals(gastosAntesDeIngreso));

    await _abrirPantallaLimite(tester);
    expect(find.text('Comida'), findsWidgets);
    await _volverAtras(tester);
    await _esperarTexto(tester, 'Mis movimientos');
  });

  testWidgets('mover un gasto a otra categoría recalcula ambos presupuestos', (
    tester,
  ) async {
    await app.main();
    await _asegurarSesion(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await _esperarTexto(tester, 'Categoría');

    final chipComida = find.widgetWithText(ChoiceChip, 'Comida');
    await tester.ensureVisible(chipComida);
    await tester.tap(chipComida);
    await tester.pump();

    final conceptoMover =
        'Gasto Mover ${DateTime.now().millisecondsSinceEpoch}';
    const montoMover = 20.0;
    await tester.enterText(_campo('Concepto'), conceptoMover);
    await tester.enterText(_campo('Monto (Bs)'), montoMover.toStringAsFixed(2));

    await _cerrarTeclado(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await _confirmarAvisoLimite(tester);

    await _esperarSinTexto(tester, 'Categor�a');
    await _esperarSinTexto(tester, 'Guardar');
    await _esperarTexto(tester, 'Mis movimientos');
    await _esperarSinSnackBar(tester);

    final botonEditar = find.byKey(ValueKey('editar-$conceptoMover'));
    final lista = find.byType(Scrollable).last;
    if (botonEditar.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(botonEditar, 200, scrollable: lista);
      } catch (_) {
        await tester.scrollUntilVisible(botonEditar, -200, scrollable: lista);
      }
    }
    await Scrollable.ensureVisible(
      tester.element(botonEditar),
      alignment: 0.0,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(botonEditar);
    await _esperarTexto(tester, 'Editar movimiento');

    final chipTransporte = find.widgetWithText(ChoiceChip, 'Transporte');
    await tester.ensureVisible(chipTransporte);
    await tester.tap(chipTransporte);
    await tester.pump();

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));

    await _esperarSinTexto(tester, 'Editar movimiento');
    await _esperarSinTexto(tester, 'Guardar cambios');
    await _esperarTexto(tester, 'Mis movimientos');
    await _esperarSinSnackBar(tester);
    if (botonEditar.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(botonEditar, 200, scrollable: lista);
      } catch (_) {
        await tester.scrollUntilVisible(botonEditar, -200, scrollable: lista);
      }
    }
    if (botonEditar.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(botonEditar, 200, scrollable: lista);
      } catch (_) {
        await tester.scrollUntilVisible(botonEditar, -200, scrollable: lista);
      }
    }
    await Scrollable.ensureVisible(
      tester.element(botonEditar),
      alignment: 0.0,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.textContaining('Transporte'), findsWidgets);

    await _abrirPantallaLimite(tester);
    expect(find.text('Presupuesto por categorías'), findsOneWidget);
    expect(find.text('Transporte'), findsWidgets);
    await _volverAtras(tester);
    await _esperarTexto(tester, 'Mis movimientos');
  });
}
