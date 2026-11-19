import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/movimiento.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_nuevo_movimiento.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

const _movimientoJson = {
  'id': 1,
  'concepto': 'Almuerzo',
  'monto': 100.0,
  'fecha': '2026-11-01',
  'tipo': 'gasto',
  'categoria': 'comida',
  'estado': 'pendiente',
  'recurrente': false,
  'frecuencia': null,
};

ApiReply _base(ApiRequest request) {
  if (request.path == '/limite') {
    return const ApiReply({
      'mes': '2026-11',
      'limite': 1000.0,
      'gastado': 200.0,
      'restante': 800.0,
    });
  }
  if (request.path == '/presupuestos-categoria') {
    return const ApiReply({
      'categorias': [
        {
          'categoria': 'comida',
          'limite': 500.0,
          'gastado': 450.0,
          'restante': 50.0,
          'proporcion': 0.9,
        },
        {
          'categoria': 'transporte',
          'limite': null,
          'gastado': 20.0,
          'restante': null,
          'proporcion': null,
        },
      ],
    });
  }
  if (request.path == '/movimientos' && request.method == 'POST') {
    return const ApiReply({'movimiento': _movimientoJson});
  }
  if (request.path == '/movimientos/1' && request.method == 'PUT') {
    return const ApiReply({'movimiento': _movimientoJson});
  }
  return const ApiReply({});
}

void main() {
  late FakeApiServer api;

  setUpAll(() async {
    api = await FakeApiServer.start();
  });

  tearDownAll(() async {
    await api.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'token-1'});
    api.handler = (request) async => _base(request);
  });

  testWidgets('valida, avisa por categoría y guarda un gasto', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaNuevoMovimiento()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.textContaining('Te quedan').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Elige una categoría'), findsOneWidget);
    expect(find.text('Completa este campo'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.enterText(_campo('Concepto'), 'Almuerzo');
    await tester.enterText(_campo('Monto (Bs)'), '100');

    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('Vas a superar el límite').evaluate().isNotEmpty,
    );
    expect(find.text('Vas a superar el límite'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Vas a superar el límite'), findsNothing);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar gasto'));
    await esperarHasta(
      tester,
      () => find.text('Movimiento guardado').evaluate().isNotEmpty,
    );
    expect(find.text('Movimiento guardado'), findsOneWidget);
  });

  testWidgets('guarda ingreso y gasto recurrente', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaNuevoMovimiento()));
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ingreso'));
    await tester.pump();
    expect(find.text('Se guardará como por cobrar.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.enterText(_campo('Concepto'), 'Beca');
    await tester.enterText(_campo('Monto (Bs)'), '200');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('Movimiento guardado').evaluate().isNotEmpty,
    );
    expect(find.text('Movimiento guardado'), findsOneWidget);

    await tester.pumpWidget(appPrueba(const PantallaNuevoMovimiento()));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semanal'));
    await tester.enterText(_campo('Concepto'), 'Pasaje');
    await tester.enterText(_campo('Monto (Bs)'), '10');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('Gasto recurrente guardado').evaluate().isNotEmpty,
    );
    expect(find.text('Gasto recurrente guardado'), findsOneWidget);
  });

  testWidgets('edita un movimiento pendiente y bloquea un pago', (tester) async {
    pantallaGrande(tester);
    final pendiente = Movimiento(
      id: 1,
      concepto: 'Almuerzo',
      monto: 100,
      fecha: DateTime(2026, 11, 1),
      categoria: CategoriaMovimiento.comida,
    );
    await tester.pumpWidget(
      appPrueba(PantallaNuevoMovimiento(movimiento: pendiente)),
    );
    await tester.pump();
    expect(find.text('Editar movimiento'), findsOneWidget);
    await tester.enterText(_campo('Concepto'), 'Cena');
    await tester.enterText(_campo('Monto (Bs)'), '90');
    await tester.tap(find.text('Guardar cambios'));
    await esperarHasta(
      tester,
      () => find.text('Cambios guardados').evaluate().isNotEmpty,
    );
    expect(find.text('Cambios guardados'), findsOneWidget);

    final pagado = Movimiento(
      id: 1,
      concepto: 'Almuerzo',
      monto: 100,
      fecha: DateTime(2026, 11, 1),
      categoria: CategoriaMovimiento.comida,
      estado: EstadoMovimiento.pagado,
    );
    await tester.pumpWidget(
      appPrueba(PantallaNuevoMovimiento(movimiento: pagado)),
    );
    await tester.pump();
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.text('Un movimiento pagado no permite modificar su monto.'), findsWidgets);
    await tester.tap(_campo('Monto (Bs)'));
    await esperarHasta(
      tester,
      () => find.text(
        'Un movimiento pagado no permite modificar su monto.',
      ).evaluate().length > 1,
    );
  });

  testWidgets('maneja bloqueo 422 y error del servidor', (tester) async {
    pantallaGrande(tester);
    var respuesta = 422;
    api.handler = (request) async {
      if (request.path == '/movimientos' && request.method == 'POST') {
        if (respuesta == 422) {
          return const ApiReply({
            'error': 'Este gasto supera el límite mensual',
          }, 422);
        }
        return const ApiReply({'error': 'No se pudo guardar'}, 500);
      }
      return _base(request);
    };

    await tester.pumpWidget(appPrueba(const PantallaNuevoMovimiento()));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.enterText(_campo('Concepto'), 'Almuerzo');
    await tester.enterText(_campo('Monto (Bs)'), '100000');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('Este gasto supera el límite mensual')
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('Este gasto supera el límite mensual'), findsOneWidget);
    expect(find.text('Cambiar monto'), findsOneWidget);
    expect(find.text('Subir límite'), findsOneWidget);

    await tester.tap(find.text('Cambiar monto'));
    await tester.pump();

    respuesta = 500;
    await tester.enterText(_campo('Monto (Bs)'), '5');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('No se pudo guardar').evaluate().isNotEmpty,
    );
    expect(find.text('No se pudo guardar'), findsOneWidget);
  });

  testWidgets('sesión expirada al guardar vuelve al login', (tester) async {
    pantallaGrande(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(appPrueba(const PantallaNuevoMovimiento()));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.enterText(_campo('Concepto'), 'Almuerzo');
    await tester.enterText(_campo('Monto (Bs)'), '10');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
