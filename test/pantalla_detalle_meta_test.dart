import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/meta_ahorro.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_detalle_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

const _metaA = {
  'id': 1,
  'nombre': 'Viaje',
  'montoObjetivo': 500.0,
  'montoReservado': 100.0,
  'fechaObjetivo': '2026-12-01',
  'progreso': 0.2,
};

const _metaB = {
  'id': 2,
  'nombre': 'Laptop',
  'montoObjetivo': 1000.0,
  'montoReservado': 0.0,
  'fechaObjetivo': '2027-01-01',
  'progreso': 0.0,
};

const _resumen = {
  'total': 500.0,
  'reservado': 100.0,
  'disponible': 400.0,
};

ApiReply _listar(ApiRequest request) {
  if (request.path == '/metas') {
    return const ApiReply({
      'metas': [_metaA, _metaB],
      'resumen': _resumen,
    });
  }
  if (request.path == '/metas/1/movimientos') {
    return const ApiReply({
      'movimientos': [
        {
          'id': 1,
          'tipo': 'asignacion',
          'monto': 100.0,
          'metaRelacionada': 'Viaje',
          'creadoEn': '2026-11-01T12:00:00.000Z',
        },
        {
          'id': 2,
          'tipo': 'retiro',
          'monto': 20.0,
          'metaRelacionada': null,
          'creadoEn': '2026-11-02T12:00:00.000Z',
        },
        {
          'id': 3,
          'tipo': 'transferencia_salida',
          'monto': 10.0,
          'metaRelacionada': 'Laptop',
          'creadoEn': '2026-11-03T12:00:00.000Z',
        },
        {
          'id': 4,
          'tipo': 'transferencia_entrada',
          'monto': 10.0,
          'metaRelacionada': 'Laptop',
          'creadoEn': '2026-11-04T12:00:00.000Z',
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
      if (request.method == 'POST') {
        return const ApiReply({'meta': _metaA, 'resumen': _resumen});
      }
      return _listar(request);
    };
  });

  testWidgets('muestra historial y opera fondos', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(
      appPrueba(
        PantallaDetalleMeta(
          meta: MetaAhorro(
            id: 1,
            nombre: 'Viaje',
            montoObjetivo: 500,
            montoReservado: 100,
            fechaObjetivo: DateTime(2026, 12, 1),
            progreso: 0.2,
          ),
        ),
      ),
    );
    await esperarHasta(
      tester,
      () => find.text('Asignar').evaluate().isNotEmpty,
    );
    expect(find.text('Objetivo: Bs 500,00'), findsOneWidget);
    expect(find.textContaining('Asignación'), findsOneWidget);
    expect(find.textContaining('Transferencia recibida'), findsOneWidget);
    expect(find.text('Meta: Viaje'), findsWidgets);

    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();
    expect(find.text('Asignar fondos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(find.text('Escribe un monto mayor a 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '50');
    await tester.tap(find.text('Confirmar'));
    await esperarHasta(
      tester,
      () => find.text('Fondos asignados').evaluate().isNotEmpty,
    );
    expect(find.text('Fondos asignados'), findsOneWidget);

    await esperarHasta(
      tester,
      () => find.text('Retirar').evaluate().isNotEmpty,
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retirar'));
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transferir'));
    await tester.pumpAndSettle();
    expect(find.text('Transferir fondos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Confirmar'));
    await esperarHasta(
      tester,
      () => find.text('Transferencia realizada').evaluate().isNotEmpty,
    );
    expect(find.text('Transferencia realizada'), findsOneWidget);
    await esperarHasta(
      tester,
      () => find.text('Asignar').evaluate().isNotEmpty,
    );
  });

  testWidgets('sin otra meta avisa y no transfiere', (tester) async {
    pantallaGrande(tester);
    api.handler = (request) async {
      if (request.path == '/metas') {
        return const ApiReply({
          'metas': [_metaA],
          'resumen': _resumen,
        });
      }
      if (request.path == '/metas/1/movimientos') {
        return const ApiReply({'movimientos': []});
      }
      return const ApiReply({});
    };

    await tester.pumpWidget(
      appPrueba(
        PantallaDetalleMeta(
          meta: MetaAhorro(
            id: 1,
            nombre: 'Viaje',
            montoObjetivo: 500,
            montoReservado: 100,
            fechaObjetivo: DateTime(2026, 12, 1),
            progreso: 0.2,
          ),
        ),
      ),
    );
    await esperarHasta(
      tester,
      () => find.text('Sin movimientos').evaluate().isNotEmpty ||
          find.text('Asignar').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Transferir'));
    await esperarHasta(
      tester,
      () => find
          .text('Necesitas al menos otra meta para transferir')
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.text('Necesitas al menos otra meta para transferir'),
      findsOneWidget,
    );
  });

  testWidgets('error de carga, reintento y error al operar', (tester) async {
    pantallaGrande(tester);
    var fallar = true;
    api.handler = (request) async {
      if (request.method == 'POST') {
        return const ApiReply({'error': 'No hay fondos'}, 400);
      }
      if (fallar) {
        return const ApiReply({'error': 'Detalle no disponible'}, 500);
      }
      return _listar(request);
    };

    await tester.pumpWidget(
      appPrueba(
        PantallaDetalleMeta(
          meta: MetaAhorro(
            id: 1,
            nombre: 'Viaje',
            montoObjetivo: 500,
            montoReservado: 100,
            fechaObjetivo: DateTime(2026, 12, 1),
            progreso: 0.2,
          ),
        ),
      ),
    );
    await esperarHasta(
      tester,
      () => find.text('Detalle no disponible').evaluate().isNotEmpty,
    );
    expect(find.text('Detalle no disponible'), findsOneWidget);

    fallar = false;
    await tester.tap(find.text('Reintentar'));
    await esperarHasta(
      tester,
      () => find.text('Asignar').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '50');
    await tester.tap(find.text('Confirmar'));
    await esperarHasta(
      tester,
      () => find.text('No hay fondos').evaluate().isNotEmpty,
    );
    expect(find.text('No hay fondos'), findsOneWidget);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      appPrueba(
        PantallaDetalleMeta(
          meta: MetaAhorro(
            id: 1,
            nombre: 'Viaje',
            montoObjetivo: 500,
            montoReservado: 100,
            fechaObjetivo: DateTime(2026, 12, 1),
            progreso: 0.2,
          ),
        ),
      ),
    );
    await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
