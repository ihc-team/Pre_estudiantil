import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/pantallas/pantalla_movimientos.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api_server.dart';
import 'helpers/test_app.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

String _fecha(int dias) {
  final d = DateTime.now().add(Duration(days: dias));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _movimiento({
  required int id,
  required String concepto,
  required double monto,
  required int dias,
  String tipo = 'gasto',
  String categoria = 'comida',
  String estado = 'pendiente',
  bool recurrente = false,
  String? frecuencia,
}) => {
  'id': id,
  'concepto': concepto,
  'monto': monto,
  'fecha': _fecha(dias),
  'tipo': tipo,
  'categoria': categoria,
  'estado': estado,
  'recurrente': recurrente,
  'frecuencia': frecuencia,
};

final _movimientosBase = [
  _movimiento(
    id: 1,
    concepto: 'Ingreso beca',
    monto: 100,
    dias: 0,
    tipo: 'ingreso',
    categoria: 'otros',
  ),
  _movimiento(id: 2, concepto: 'Almuerzo vencido', monto: 20, dias: -5),
  _movimiento(
    id: 3,
    concepto: 'Pasaje pagado',
    monto: 30,
    dias: -10,
    categoria: 'transporte',
    estado: 'pagado',
  ),
  _movimiento(
    id: 4,
    concepto: 'Curso futuro',
    monto: 10,
    dias: 20,
    categoria: 'estudio',
    recurrente: true,
    frecuencia: 'mensual',
  ),
];

ApiReply _respuesta(ApiRequest request) {
  switch (request.path) {
    case '/perfil':
      return const ApiReply({'nombre': 'Ana'});
    case '/movimientos':
      if (request.method == 'POST') {
        return ApiReply({'movimiento': _movimientosBase.first});
      }
      return ApiReply({
        'movimientos': _movimientosBase,
        'totales': {'cantidad': _movimientosBase.length, 'ingresos': 100, 'gastos': 60},
      });
    case '/movimientos/2/pagar':
      return ApiReply({
        'movimiento': {..._movimientosBase[1], 'estado': 'pagado'},
      });
    case '/limite':
      if (request.method == 'PUT') {
        return const ApiReply({
          'mes': '2026-11',
          'limite': 1000.0,
          'gastado': 200.0,
          'restante': 800.0,
        });
      }
      return const ApiReply({
        'mes': '2026-11',
        'limite': 1000.0,
        'gastado': 200.0,
        'restante': 800.0,
      });
    case '/presupuestos-categoria':
      return const ApiReply({
        'categorias': [
          {
            'categoria': 'comida',
            'limite': 100.0,
            'gastado': 150.0,
            'restante': -50.0,
            'proporcion': 1.5,
          },
        ],
      });
    case '/metas':
      return const ApiReply({
        'metas': [],
        'resumen': {'total': 500, 'reservado': 100, 'disponible': 400},
      });
    case '/historial':
      return const ApiReply({'grupos': []});
    case '/cuenta/exportar':
      return const ApiReply({
        'usuario': {'nombre': 'Ana', 'correo': 'ana@correo.com'},
        'movimientos': [],
        'metas': [],
        'presupuestosCategorias': [],
      });
    case '/cuenta':
      return const ApiReply({});
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
    SharedPreferences.setMockInitialValues({'token': 'token-1'});
    api.handler = (request) async => _respuesta(request);
  });

  testWidgets('lista, agrupa, filtra y busca movimientos', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Ingreso beca').evaluate().isNotEmpty,
    );

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ingreso beca'), findsOneWidget);
    expect(find.text('Almuerzo vencido'), findsOneWidget);
    expect(find.text('Pasaje pagado'), findsOneWidget);
    expect(find.text('Curso futuro'), findsOneWidget);
    expect(find.textContaining('Atencion: Te pasaste en comida'), findsOneWidget);
    expect(find.text('Disponible Bs 400,00'), findsOneWidget);
    expect(find.text('4 movimientos'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendientes'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pagados'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Recurrentes'));
    await tester.pump();
    expect(find.text('Curso futuro'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pump();

    await tester.enterText(_campo('Buscar por concepto'), 'Almuerzo');
    await tester.pump(const Duration(milliseconds: 500));
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await esperarHasta(
      tester,
      () => find.byType(InputChip).evaluate().isNotEmpty,
    );

    final chip = tester.widget<InputChip>(find.byType(InputChip).first);
    chip.onDeleted!();
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.byType(InputChip).evaluate().isEmpty,
    );

    await tester.enterText(_campo('Buscar por concepto'), 'Almuerzo');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await esperarHasta(
      tester,
      () => find.widgetWithText(TextButton, 'Quitar todos').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Quitar todos'));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Ingreso beca').evaluate().isNotEmpty,
    );
  });

  testWidgets('paga, elimina, edita y abre formularios', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(
      find.widgetWithText(TextButton, 'Marcar como pagado').first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Marcar como pagado'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(TextButton, 'Marcar como pagado').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await esperarHasta(
      tester,
      () => find.text('Marcado como pagado').evaluate().isNotEmpty,
    );
    expect(find.text('Marcado como pagado'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    final eliminar = find.byKey(const ValueKey('eliminar-Almuerzo vencido'));
    await tester.ensureVisible(eliminar);
    await tester.tap(eliminar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await esperarHasta(
      tester,
      () => find.text('Movimiento eliminado').evaluate().isNotEmpty,
    );
    expect(find.text('Movimiento eliminado'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    final editar = find.byKey(const ValueKey('editar-Almuerzo vencido'));
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Editar movimiento').evaluate().isNotEmpty,
    );
    expect(find.text('Editar movimiento'), findsOneWidget);
    Navigator.of(
      tester.element(find.text('Editar movimiento')),
    ).pop(true);

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    fab.onPressed!();
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Nuevo movimiento').evaluate().length > 1,
    );
    Navigator.of(
      tester.element(find.text('Nuevo movimiento').last),
    ).pop(true);
  });

  testWidgets('abre historial, límite, metas y mis datos', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Historial'));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Historial').evaluate().length > 1,
    );
    await tester.pageBack();
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Límite'));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Presupuesto por categorías').evaluate().isNotEmpty,
    );
    await tester.pageBack();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Ver metas'));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Metas de ahorro').evaluate().isNotEmpty,
    );
    await tester.pageBack();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis datos'));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Descargar mis datos (JSON)').evaluate().isNotEmpty,
    );
    await tester.pageBack();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );
  });

  testWidgets('cierra sesión y elimina cuenta', (tester) async {
    pantallaGrande(tester);
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await esperarHasta(
      tester,
      () => find.text('Iniciar sesión').evaluate().isNotEmpty,
    );
    expect(find.text('Iniciar sesión'), findsOneWidget);

    SharedPreferences.setMockInitialValues({'token': 'token-1'});
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar cuenta y datos'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    await tester.enterText(_campo('Contraseña actual'), '123456');
    await tester.tap(find.text('Eliminar'));
    await esperarHasta(
      tester,
      () => find.text('Iniciar sesión').evaluate().isNotEmpty,
    );
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('estados vacíos, error y sesión inválida', (tester) async {
    pantallaGrande(tester);
    api.handler = (request) async {
      if (request.path == '/movimientos') {
        return const ApiReply({
          'movimientos': [],
          'totales': {'cantidad': 0, 'ingresos': 0, 'gastos': 0},
        });
      }
      return _respuesta(request);
    };

    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await esperarHasta(
      tester,
      () => find.textContaining('Aún no tienes movimientos').evaluate().isNotEmpty,
    );
    expect(find.textContaining('Aún no tienes movimientos'), findsOneWidget);

    for (final chip in ['Pendientes', 'Pagados', 'Recurrentes']) {
      await tester.tap(find.widgetWithText(ChoiceChip, chip));
      await tester.pump();
    }
    expect(find.textContaining('No tienes gastos recurrentes'), findsOneWidget);

    api.handler = (request) async {
      if (request.path == '/movimientos') {
        return const ApiReply({'error': 'No se pudo cargar la lista'}, 500);
      }
      return _respuesta(request);
    };
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await esperarHasta(
      tester,
      () => find.text('No se pudo cargar la lista').evaluate().isNotEmpty,
    );
    expect(find.text('No se pudo cargar la lista'), findsOneWidget);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await esperarHasta(tester, () => find.text('Entrar').evaluate().isNotEmpty);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('búsqueda sin resultados y quitar filtros', (tester) async {
    pantallaGrande(tester);
    api.handler = (request) async {
      if (request.path == '/movimientos' &&
          request.query['buscar'] == 'inexistente') {
        return const ApiReply({
          'movimientos': [],
          'totales': {'cantidad': 0, 'ingresos': 0, 'gastos': 0},
        });
      }
      return _respuesta(request);
    };

    await tester.pumpWidget(appPrueba(const PantallaMovimientos()));
    await tester.pump();
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );
    await tester.enterText(_campo('Buscar por concepto'), 'inexistente');
    await tester.pump(const Duration(milliseconds: 500));
    await esperarHasta(
      tester,
      () => find.textContaining('Ningún movimiento coincide').evaluate().isNotEmpty,
    );
    expect(find.text('Quitar filtros'), findsOneWidget);
    await tester.tap(find.text('Quitar filtros'));
    await esperarHasta(
      tester,
      () => find.text('Almuerzo vencido').evaluate().isNotEmpty,
    );
  });
}
