import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_limite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

ApiReply _limiteBase(ApiRequest request) {
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
          'limite': 100.0,
          'gastado': 150.0,
          'restante': -50.0,
          'proporcion': 1.5,
        },
        {
          'categoria': 'estudio',
          'limite': null,
          'gastado': 0.0,
          'restante': null,
          'proporcion': null,
        },
        {
          'categoria': 'otros',
          'limite': 300.0,
          'gastado': 100.0,
          'restante': 200.0,
          'proporcion': 0.3,
        },
      ],
    });
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
    api.handler = (request) async {
      if (request.method == 'PUT') {
        return const ApiReply({
          'mes': '2026-11',
          'limite': 1200.0,
          'gastado': 200.0,
          'restante': 1000.0,
        });
      }
      return _limiteBase(request);
    };
  });

  testWidgets('muestra estados, guarda, valida y edita categorías', (
    tester,
  ) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaLimite()));
    await esperarHasta(
      tester,
      () => find.text('Comida').evaluate().isNotEmpty,
    );

    expect(find.text('Presupuesto por categorías'), findsOneWidget);
    expect(find.textContaining('Estas cerca del limite'), findsOneWidget);
    expect(find.textContaining('Excedido por'), findsOneWidget);
    expect(find.text('Toca para definir un presupuesto'), findsOneWidget);

    await tester.enterText(_campo('Límite del mes (Bs)'), '');
    await tester.tap(find.text('Guardar límite'));
    await tester.pump();
    expect(find.text('Escribe el límite'), findsOneWidget);

    await tester.enterText(_campo('Límite del mes (Bs)'), '1200');
    await tester.tap(find.text('Guardar límite'));
    await esperarHasta(
      tester,
      () => find.textContaining('Límite guardado').evaluate().isNotEmpty,
    );
    expect(find.textContaining('Límite guardado'), findsOneWidget);

    await tester.ensureVisible(find.text('Comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();
    expect(find.text('Presupuesto (Bs)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Comida'));
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();
    await tester.enterText(_campo('Presupuesto (Bs)'), '0');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.textContaining('El límite debe ser').evaluate().isNotEmpty,
    );
    expect(find.textContaining('El límite debe ser'), findsOneWidget);

    await tester.enterText(_campo('Presupuesto (Bs)'), '600');
    await tester.tap(find.text('Guardar'));
    await esperarHasta(
      tester,
      () => find.text('Presupuesto (Bs)').evaluate().isEmpty,
    );
    expect(find.text('Comida'), findsWidgets);

    await tester.ensureVisible(find.text('Listo'));
    await tester.tap(find.text('Listo'));
    await tester.pump();
  });

  testWidgets('navega meses, soporta límite nulo y errores', (tester) async {
    pantallaGrande(tester);
    api.handler = (request) async {
      if (request.method == 'PUT') {
        return const ApiReply({'error': 'No se pudo guardar'}, 500);
      }
      if (request.path == '/limite') {
        return const ApiReply({
          'mes': null,
          'limite': null,
          'gastado': 0.0,
          'restante': null,
        });
      }
      if (request.path == '/presupuestos-categoria') {
        return const ApiReply({'categorias': []});
      }
      return const ApiReply({});
    };

    await tester.pumpWidget(appPrueba(const PantallaLimite()));
    await esperarHasta(
      tester,
      () => find.text('Presupuesto por categorías').evaluate().isNotEmpty,
    );
    expect(find.text('Límite del mes'), findsOneWidget);

    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pump();
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pump();

    await tester.enterText(_campo('Límite del mes (Bs)'), '500');
    await tester.tap(find.text('Guardar límite'));
    await esperarHasta(
      tester,
      () => find.text('No se pudo guardar').evaluate().isNotEmpty,
    );
    expect(find.text('No se pudo guardar'), findsOneWidget);
  });

  testWidgets('error de carga y sesión expirada', (tester) async {
    pantallaGrande(tester);
    api.handler = (request) async =>
        const ApiReply({'error': 'Fallo de límite'}, 500);

    await tester.pumpWidget(appPrueba(const PantallaLimite()));
    await esperarHasta(
      tester,
      () => find.text('Fallo de límite').evaluate().isNotEmpty,
    );
    expect(find.text('Fallo de límite'), findsOneWidget);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(appPrueba(const PantallaLimite()));
    await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
