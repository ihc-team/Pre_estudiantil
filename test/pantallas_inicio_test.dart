import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/configuracion/constantes.dart';
import 'package:ihcpre_estudiantil2/configuracion/rutas.dart';
import 'package:ihcpre_estudiantil2/configuracion/tema.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_arranque.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_inicio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';

Widget _app(Widget home) => MaterialApp(
  key: UniqueKey(),
  theme: TemaApp.temaClaro,
  home: home,
  onGenerateRoute: (settings) {
    final constructor = Rutas.mapa[settings.name];
    if (constructor == null) return null;
    return MaterialPageRoute(
      settings: settings,
      builder: constructor,
    );
  },
);

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Inicio navega a login, registro y recuperación', (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_app(const PantallaInicio()));
    expect(find.text('TU DINERO, TUS METAS'), findsOneWidget);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);

    await tester.pumpWidget(_app(const PantallaInicio()));
    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();
    expect(find.text('Crear cuenta'), findsOneWidget);

    await tester.pumpWidget(_app(const PantallaInicio()));
    await tester.tap(find.byIcon(Icons.lock_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('Obtener código'), findsOneWidget);
  });

  test('el mapa de rutas contiene las pantallas esperadas', () {
    expect(Rutas.mapa.length, 12);
    expect(Rutas.mapa.containsKey(Rutas.inicio), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.login), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.registro), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.recuperar), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.movimientos), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.nuevoMovimiento), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.limite), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.historial), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.metas), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.analitica), isTrue);
    expect(Rutas.mapa.containsKey(Rutas.misDatos), isTrue);
  });

  group('PantallaArranque', () {
    late FakeApiServer api;

    setUpAll(() async {
      api = await FakeApiServer.start();
    });

    tearDownAll(() async {
      await api.close();
    });

    setUp(() {
      api.handler = (request) async {
        switch (request.path) {
          case '/perfil':
            return const ApiReply({'nombre': 'Ana'});
          case '/movimientos':
            return const ApiReply({
              'movimientos': [],
              'totales': {'cantidad': 0, 'ingresos': 0, 'gastos': 0},
            });
          case '/limite':
            return const ApiReply({
              'mes': '2026-11',
              'limite': null,
              'gastado': 0,
              'restante': null,
            });
          case '/presupuestos-categoria':
            return const ApiReply({'categorias': []});
          case '/metas':
            return const ApiReply({
              'metas': [],
              'resumen': {'total': 0, 'reservado': 0, 'disponible': 0},
            });
          default:
            return const ApiReply({});
        }
      };
    });

    testWidgets('con sesión abre movimientos', (tester) async {
      _pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({'token': 'token-1'});
      await tester.pumpWidget(_app(const PantallaArranque()));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.text('Mis movimientos').evaluate().isNotEmpty) break;
      }
      expect(find.text('Mis movimientos'), findsOneWidget);
    });

    testWidgets('sin sesión abre inicio', (tester) async {
      _pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(const PantallaArranque()));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('sin conexión muestra reintento', (tester) async {
      _pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({'token': 'token-1'});
      final base = dotenv.env['API_BASE_URL'];
      dotenv.env['API_BASE_URL'] = 'http://127.0.0.1:1';

      await tester.pumpWidget(_app(const PantallaArranque()));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.text('No se pudo conectar con el servidor')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      dotenv.env['API_BASE_URL'] = base ?? dotenv.env['API_BASE_URL']!;
      await tester.tap(find.text('Reintentar'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.text('Mis movimientos').evaluate().isNotEmpty) break;
      }
      expect(find.text('Mis movimientos'), findsOneWidget);
    });
  });

  test('el servidor usa el valor de dotenv o el fallback', () {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:3000');
    expect(Servidor.urlBase, 'http://localhost:3000');
  });
}
