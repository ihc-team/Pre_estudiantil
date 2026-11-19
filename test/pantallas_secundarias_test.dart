import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_analitica.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_historial.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_metas.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_mis_datos.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_nueva_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

const _metaJson = {
  'id': 1,
  'nombre': 'Viaje',
  'montoObjetivo': 500.0,
  'montoReservado': 100.0,
  'fechaObjetivo': '2026-12-01',
  'progreso': 0.2,
};

const _resumenMetasJson = {
  'total': 500.0,
  'reservado': 100.0,
  'disponible': 400.0,
};

const _datosCuenta = {
  'usuario': {
    'nombre': 'Ana Torres',
    'correo': 'ana@correo.com',
    'miembroDesde': '01/01/2026',
  },
  'movimientos': [
    {'id': 1},
    {'id': 2},
  ],
  'metas': [
    {'id': 1},
  ],
  'presupuestosCategorias': [
    {'categoria': 'comida'},
  ],
};

const _eventoBase = {
  'tipo': 'gasto_registrado',
  'movimientoId': 1,
  'hora': '12:00',
  'creadoEn': '2026-11-01T12:00:00.000Z',
};

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
  });

  group('Historial', () {
    testWidgets('muestra todos los tipos, filtra y vuelve a todos', (
      tester,
    ) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/historial') {
          return const ApiReply({
            'grupos': [
              {
                'titulo': 'Hoy',
                'eventos': [
                  {..._eventoBase, 'id': 1, 'monto': 15.0, 'descripcion': 'Almuerzo'},
                  {
                    'id': 2,
                    'tipo': 'ingreso_registrado',
                    'monto': 100.0,
                    'descripcion': 'Beca',
                    'movimientoId': 2,
                    'hora': '13:00',
                    'creadoEn': '2026-11-01T13:00:00.000Z',
                  },
                  {
                    'id': 3,
                    'tipo': 'movimiento_pagado',
                    'monto': null,
                    'descripcion': '',
                    'movimientoId': null,
                    'hora': '14:00',
                    'creadoEn': '2026-11-01T14:00:00.000Z',
                  },
                  {
                    'id': 4,
                    'tipo': 'limite_definido',
                    'monto': 500.0,
                    'descripcion': 'Límite mensual',
                    'movimientoId': null,
                    'hora': '15:00',
                    'creadoEn': '2026-11-01T15:00:00.000Z',
                  },
                ],
              },
            ],
          });
        }
        return const ApiReply({});
      };

      await tester.pumpWidget(appPrueba(const PantallaHistorial()));
      await esperarHasta(tester, () => find.text('Hoy').evaluate().isNotEmpty);

      expect(find.text('Registraste gasto: Almuerzo'), findsOneWidget);
      expect(find.text('Registraste ingreso: Beca'), findsOneWidget);
      expect(find.text('Marcaste como pagado un movimiento'), findsOneWidget);
      expect(find.text('Definiste tu límite: Límite mensual'), findsOneWidget);
      expect(find.text('Bs 15,00'), findsOneWidget);

      final chips = ['Gastos', 'Ingresos', 'Pagos', 'Límite', 'Todos'];
      for (final texto in chips) {
        await tester.tap(find.widgetWithText(ChoiceChip, texto));
        await esperarHasta(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
      }
      expect(find.text('Registraste gasto: Almuerzo'), findsOneWidget);
    });

    testWidgets('estado vacío general y filtrado', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async =>
          const ApiReply({'grupos': <Object>[]});

      await tester.pumpWidget(appPrueba(const PantallaHistorial()));
      await esperarHasta(
        tester,
        () => find.textContaining('Todavía no hay actividad').evaluate().isNotEmpty,
      );
      expect(find.text('Registrar gasto'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gastos'));
      await esperarHasta(
        tester,
        () => find.textContaining('No hay actividad para').evaluate().isNotEmpty,
      );
      expect(find.text('Ver todos'), findsOneWidget);

      await tester.tap(find.text('Ver todos'));
      await esperarHasta(
        tester,
        () => find.textContaining('Todavía no hay actividad').evaluate().isNotEmpty,
      );
    });

    testWidgets('muestra error del servidor y sesión expirada', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async =>
          const ApiReply({'error': 'No se pudo cargar'}, 500);

      await tester.pumpWidget(appPrueba(const PantallaHistorial()));
      await esperarHasta(
        tester,
        () => find.text('No se pudo cargar el historial').evaluate().isNotEmpty,
      );
      expect(find.text('No se pudo cargar el historial'), findsOneWidget);

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(appPrueba(const PantallaHistorial()));
      await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('Mis datos', () {
    testWidgets('muestra la cuenta y descarga el JSON', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/cuenta/exportar') {
          return const ApiReply(_datosCuenta);
        }
        return const ApiReply({});
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') return null;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(appPrueba(const PantallaMisDatos()));
      await esperarHasta(
        tester,
        () => find.text('Descargar mis datos (JSON)').evaluate().isNotEmpty,
      );
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));

      await tester.tap(find.text('Descargar mis datos (JSON)'));
      await esperarHasta(
        tester,
        () => find.textContaining('Tus datos en formato JSON').evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('Tus datos en formato JSON'),
        findsOneWidget,
      );

      await tester.tap(find.text('Eliminar mi cuenta y datos'));
      await tester.pump();
    });

    testWidgets('error, reintento y respuesta inválida', (tester) async {
      pantallaGrande(tester);
      var fallar = true;
      api.handler = (request) async {
        if (fallar) return const ApiReply({'error': 'No disponible'}, 500);
        return const ApiReply(_datosCuenta);
      };

      await tester.pumpWidget(appPrueba(const PantallaMisDatos()));
      await esperarHasta(
        tester,
        () => find.text('No disponible').evaluate().isNotEmpty,
      );
      expect(find.text('No disponible'), findsOneWidget);

      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await esperarHasta(
        tester,
        () => find.text('Descargar mis datos (JSON)').evaluate().isNotEmpty,
      );
      expect(find.text('Descargar mis datos (JSON)'), findsOneWidget);

      api.handler = (request) async => const ApiReply('respuesta inválida');
      await tester.pumpWidget(appPrueba(const PantallaMisDatos()));
      await esperarHasta(
        tester,
        () => find.text('No se pudieron cargar tus datos').evaluate().isNotEmpty,
      );
      expect(find.text('No se pudieron cargar tus datos'), findsOneWidget);
    });

    testWidgets('sesión expirada vuelve al login', (tester) async {
      pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(appPrueba(const PantallaMisDatos()));
      await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('Metas', () {
    testWidgets('crea, abre detalle y recarga', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async {
        if (request.path == '/metas') {
          return const ApiReply({
            'metas': [_metaJson],
            'resumen': _resumenMetasJson,
          });
        }
        if (request.path == '/metas/1/movimientos') {
          return const ApiReply({'movimientos': []});
        }
        return const ApiReply({});
      };

      await tester.pumpWidget(appPrueba(const PantallaMetas()));
      await esperarHasta(
        tester,
        () => find.text('Viaje').evaluate().isNotEmpty,
      );
      expect(find.text('Saldos'), findsOneWidget);
      expect(find.text('Total Bs 500,00'), findsOneWidget);

      await tester.tap(find.text('Nueva meta'));
      await tester.pumpAndSettle();
      expect(find.byType(PantallaNuevaMeta), findsOneWidget);
      Navigator.of(
        tester.element(find.byType(PantallaNuevaMeta)),
      ).pop(true);
      await esperarHasta(
        tester,
        () => find.text('Viaje').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Viaje'));
      await tester.pump();
      await esperarHasta(
        tester,
        () => find.text('Asignar').evaluate().isNotEmpty,
      );
      expect(find.text('Asignar'), findsOneWidget);
      Navigator.of(tester.element(find.byType(PantallaMetas))).pop();
      await esperarHasta(
        tester,
        () => find.text('Viaje').evaluate().isNotEmpty,
      );
    });

    testWidgets('lista vacía', (tester) async {
      pantallaGrande(tester);
      api.handler = (request) async => const ApiReply({
        'metas': [],
        'resumen': _resumenMetasJson,
      });
      await tester.pumpWidget(appPrueba(const PantallaMetas()));
      await esperarHasta(
        tester,
        () => find.textContaining('Aún no tienes metas').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Aún no tienes metas'), findsOneWidget);
    });

    testWidgets('error, reintento y sesión expirada', (tester) async {
      pantallaGrande(tester);
      var fallar = true;
      api.handler = (request) async {
        if (fallar) return const ApiReply({'error': 'Fallo de metas'}, 500);
        return const ApiReply({
          'metas': [_metaJson],
          'resumen': _resumenMetasJson,
        });
      };

      await tester.pumpWidget(appPrueba(const PantallaMetas()));
      await esperarHasta(
        tester,
        () => find.text('Fallo de metas').evaluate().isNotEmpty,
      );
      expect(find.text('Fallo de metas'), findsOneWidget);

      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await esperarHasta(
        tester,
        () => find.text('Viaje').evaluate().isNotEmpty,
      );
      expect(find.text('Viaje'), findsOneWidget);

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(appPrueba(const PantallaMetas()));
      await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('Analítica', () {
    testWidgets('muestra embudos, fricción y últimos eventos', (tester) async {
      pantallaGrande(tester);
      final eventos = [
        {'evento': 'movimiento_iniciado', 'props': {'tipo': 'gasto'}, 'fecha': '2026-11-01'},
        {'evento': 'movimiento_guardado', 'props': {'tipo': 'gasto'}, 'fecha': '2026-11-01'},
        {'evento': 'meta_creacion_iniciada', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'meta_guardada', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'fondos_meta_operados', 'props': {'operacion': 'asignar'}, 'fecha': '2026-11-01'},
        {'evento': 'limite_iniciado', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'limite_guardado', 'props': {'alcance': 'general'}, 'fecha': '2026-11-01'},
        {'evento': 'aviso_limite_mostrado', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'aviso_limite_confirmado', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'aviso_limite_cancelado', 'props': {}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'monto_vacio'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'concepto_vacio'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'monto_invalido'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'categoria_vacia'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'fecha_vacia'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'validacion_invalida'}, 'fecha': '2026-11-01'},
        {'evento': 'error_formulario_mostrado', 'props': {'motivo': 'otro'}, 'fecha': '2026-11-01'},
        {'evento': 'busqueda_sin_resultados', 'props': {'origen': 'texto'}, 'fecha': '2026-11-01'},
      ];
      SharedPreferences.setMockInitialValues({
        'tabla_eventos_analitica': jsonEncode(eventos),
      });

      await tester.pumpWidget(appPrueba(const PantallaAnalitica()));
      await esperarHasta(
        tester,
        () => find.text('Búsquedas sin resultados: 1').evaluate().isNotEmpty,
      );
      expect(find.text('Embudos de los flujos principales'), findsOneWidget);
      expect(find.text('Operaciones de fondos: 1'), findsOneWidget);
      expect(find.textContaining('Concepto vacío: 1'), findsOneWidget);
      expect(find.textContaining('Monto vacío: 1'), findsOneWidget);
      expect(find.textContaining('otro: 1'), findsOneWidget);
      expect(find.text('movimiento_guardado'), findsWidgets);

      await tester.tap(find.byIcon(Icons.refresh));
      await esperarHasta(
        tester,
        () => find.text('Búsquedas sin resultados: 1').evaluate().isNotEmpty,
      );
    });

    testWidgets('estado vacío y datos corruptos', (tester) async {
      pantallaGrande(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(appPrueba(const PantallaAnalitica()));
      await esperarHasta(
        tester,
        () => find.text('Aun no hay eventos registrados.').evaluate().isNotEmpty,
      );
      expect(find.text('Sin errores registrados'), findsOneWidget);

      SharedPreferences.setMockInitialValues({
        'tabla_eventos_analitica': 'no es json',
      });
      await tester.pumpWidget(appPrueba(const PantallaAnalitica()));
      await esperarHasta(
        tester,
        () => find.text('Aun no hay eventos registrados.').evaluate().isNotEmpty,
      );
      expect(find.text('Sin errores registrados'), findsOneWidget);
    });
  });
}
