import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_login.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_nueva_meta.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_recuperar.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_registro.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

const _movimientoJson = {
  'id': 1,
  'concepto': 'Almuerzo',
  'monto': 10.0,
  'fecha': '2026-11-01',
  'tipo': 'gasto',
  'categoria': 'comida',
  'estado': 'pendiente',
  'recurrente': false,
  'frecuencia': null,
};

ApiReply _respuestaBase(ApiRequest request) {
  switch (request.path) {
    case '/perfil':
      return const ApiReply({'nombre': 'Ana'});
    case '/movimientos':
      return const ApiReply({
        'movimientos': [_movimientoJson],
        'totales': {'cantidad': 1, 'ingresos': 0, 'gastos': 10},
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
      if (request.method == 'POST') {
        return const ApiReply({
          'meta': {
            'id': 1,
            'nombre': 'Viaje',
            'montoObjetivo': 500.0,
            'montoReservado': 0.0,
            'fechaObjetivo': '2026-12-01',
            'progreso': 0.0,
          },
          'resumen': {'total': 500, 'reservado': 0, 'disponible': 500},
        });
      }
      return const ApiReply({
        'metas': [],
        'resumen': {'total': 0, 'reservado': 0, 'disponible': 0},
      });
    default:
      return const ApiReply({});
  }
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
    SharedPreferences.setMockInitialValues({});
    api.handler = (request) async => _respuestaBase(request);
  });

  group('Login', () {
    testWidgets('inicia sesión y entra a movimientos', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/login') {
          return const ApiReply({'token': 'token-1'});
        }
        return _respuestaBase(request);
      };

      await tester.pumpWidget(appPrueba(const PantallaLogin()));
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.enterText(_campo('Contraseña'), '123456');
      await tester.tap(find.text('Entrar'));
      await esperarHasta(
        tester,
        () => find.text('Mis movimientos').evaluate().isNotEmpty,
      );
      expect(find.text('Mis movimientos'), findsOneWidget);
    });

    testWidgets('muestra credenciales inválidas', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/login') {
          return const ApiReply({'error': 'Credenciales inválidas'}, 401);
        }
        return _respuestaBase(request);
      };

      await tester.pumpWidget(appPrueba(const PantallaLogin()));
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.enterText(_campo('Contraseña'), 'incorrecta');
      await tester.tap(find.text('Entrar'));
      await esperarHasta(
        tester,
        () => find.text('Credenciales inválidas').evaluate().isNotEmpty,
      );
      expect(find.text('Credenciales inválidas'), findsOneWidget);
    });

    testWidgets('navega a registro y recuperación', (tester) async {
      await tester.pumpWidget(appPrueba(const PantallaLogin()));

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(find.text('Obtener código'), findsOneWidget);
    });
  });

  group('Registro', () {
    testWidgets('valida correo, contraseña y confirmación', (tester) async {
      pantallaGrande(tester);
      await tester.pumpWidget(appPrueba(const PantallaRegistro()));

      await tester.enterText(_campo('Nombre'), 'Ana');
      await tester.enterText(_campo('Correo'), 'correo-invalido');
      await tester.enterText(_campo('Contraseña'), '123456');
      await tester.enterText(_campo('Repetir contraseña'), '654321');
      await tester.tap(find.text('Registrarse'));
      await tester.pump();

      expect(find.textContaining('correo válido'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

      await tester.enterText(_campo('Contraseña'), '123');
      await tester.enterText(_campo('Repetir contraseña'), '123');
      await tester.tap(find.text('Registrarse'));
      await tester.pump();
      expect(
        find.text('La contraseña debe tener mínimo 6 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets('crea la cuenta y vuelve al login', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/registro') return const ApiReply({});
        return _respuestaBase(request);
      };

      await tester.pumpWidget(appPrueba(const PantallaRegistro()));
      await tester.enterText(_campo('Nombre'), 'Ana');
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.enterText(_campo('Contraseña'), '123456');
      await tester.enterText(_campo('Repetir contraseña'), '123456');
      await tester.tap(find.text('Registrarse'));
      await esperarHasta(
        tester,
        () => find.text('Entrar').evaluate().isNotEmpty,
      );
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('muestra error del servidor', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async =>
          const ApiReply({'error': 'Correo ya registrado'}, 400);

      await tester.pumpWidget(appPrueba(const PantallaRegistro()));
      await tester.enterText(_campo('Nombre'), 'Ana');
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.enterText(_campo('Contraseña'), '123456');
      await tester.enterText(_campo('Repetir contraseña'), '123456');
      await tester.tap(find.text('Registrarse'));
      await esperarHasta(
        tester,
        () => find.text('Correo ya registrado').evaluate().isNotEmpty,
      );
      expect(find.text('Correo ya registrado'), findsOneWidget);
    });
  });

  group('Recuperación', () {
    testWidgets('pide código, valida y cambia contraseña', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/recuperar') {
          return const ApiReply({'codigo': '123456'});
        }
        if (request.path == '/cambiar-contrasena') return const ApiReply({});
        return _respuestaBase(request);
      };

      await tester.pumpWidget(appPrueba(const PantallaRecuperar()));
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.tap(find.text('Obtener código'));
      await esperarHasta(
        tester,
        () => find.text('123456').evaluate().isNotEmpty,
      );
      expect(find.text('123456'), findsOneWidget);

      await tester.enterText(_campo('Código'), '123456');
      await tester.enterText(_campo('Nueva contraseña'), '123');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pump();
      expect(
        find.text('La contraseña debe tener mínimo 6 caracteres'),
        findsOneWidget,
      );

      await tester.enterText(_campo('Nueva contraseña'), '123456');
      await tester.tap(find.text('Cambiar contraseña'));
      await esperarHasta(
        tester,
        () => find.text('Entrar').evaluate().isNotEmpty,
      );
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('cambia de correo y muestra error del servidor', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/recuperar') {
          return const ApiReply({'error': 'Correo no registrado'}, 404);
        }
        return _respuestaBase(request);
      };

      await tester.pumpWidget(appPrueba(const PantallaRecuperar()));
      await tester.enterText(_campo('Correo'), 'ana@correo.com');
      await tester.tap(find.text('Obtener código'));
      await esperarHasta(
        tester,
        () => find.text('Correo no registrado').evaluate().isNotEmpty,
      );
      expect(find.text('Correo no registrado'), findsOneWidget);

      api.handler = (request) async =>
          const ApiReply({'codigo': '654321'});
      await tester.tap(find.text('Obtener código'));
      await esperarHasta(
        tester,
        () => find.text('654321').evaluate().isNotEmpty,
      );
      expect(find.text('Cambiar correo'), findsOneWidget);
      await tester.tap(find.text('Cambiar correo'));
      await tester.pump();
      expect(find.text('Obtener código'), findsOneWidget);
    });
  });

  group('Nueva meta', () {
    testWidgets('valida monto y crea la meta', (tester) async {
      pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({'token': 'token-1'});
      api.handler = (request) async => _respuestaBase(request);

      await tester.pumpWidget(appPrueba(const PantallaNuevaMeta()));
      await tester.enterText(_campo('Nombre de la meta'), 'Viaje');
      await tester.enterText(_campo('Monto objetivo (Bs)'), '0');
      await tester.tap(find.text('Guardar meta'));
      await tester.pump();
      expect(find.text('El monto debe ser mayor a 0'), findsOneWidget);

      await tester.enterText(_campo('Monto objetivo (Bs)'), '500');
      await tester.tap(find.text('Guardar meta'));
      await esperarHasta(
        tester,
        () => find.text('Meta creada').evaluate().isNotEmpty,
      );
      expect(find.text('Meta creada'), findsOneWidget);
    });

    testWidgets('muestra error del servidor y sesión expirada', (tester) async {
      pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({'token': 'token-1'});
      api.handler = (request) async =>
          const ApiReply({'error': 'No se pudo crear'}, 500);

      await tester.pumpWidget(appPrueba(const PantallaNuevaMeta()));
      await tester.enterText(_campo('Nombre de la meta'), 'Viaje');
      await tester.enterText(_campo('Monto objetivo (Bs)'), '500');
      await tester.tap(find.text('Guardar meta'));
      await esperarHasta(
        tester,
        () => find.text('No se pudo crear').evaluate().isNotEmpty,
      );
      expect(find.text('No se pudo crear'), findsOneWidget);

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(appPrueba(const PantallaNuevaMeta()));
      await tester.enterText(_campo('Nombre de la meta'), 'Viaje');
      await tester.enterText(_campo('Monto objetivo (Bs)'), '500');
      await tester.tap(find.text('Guardar meta'));
      await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });
}
