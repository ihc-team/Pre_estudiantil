import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/filtros.dart';
import 'package:ihcpre_estudiantil2/modelos/movimiento.dart';
import 'package:ihcpre_estudiantil2/widgets/hoja_filtros.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('aplica categoría, periodo y rango de fechas', (tester) async {
    pantallaGrande(tester);
    FiltrosMovimientos? resultado;
    await tester.pumpWidget(
      appPrueba(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarHojaFiltros(
                  context,
                  FiltrosMovimientos.vacio,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Filtros'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rango de fechas'));
    await tester.pump();

    expect(find.text('Desde'), findsOneWidget);
    expect(find.text('Hasta'), findsOneWidget);

    await tester.tap(find.text('Desde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.categoria, CategoriaMovimiento.comida);
    expect(resultado!.periodo, PeriodoFiltro.rango);
    expect(resultado!.desde, isNotNull);
    expect(resultado!.hasta, isNotNull);
  });

  testWidgets('muestra más filtros, limpia y valida el rango', (tester) async {
    pantallaGrande(tester);
    FiltrosMovimientos? resultado;
    await tester.pumpWidget(
      appPrueba(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarHojaFiltros(
                  context,
                  FiltrosMovimientos(
                    buscar: 'x',
                    tipo: TipoMovimiento.gasto,
                    estado: EstadoMovimiento.pendiente,
                    periodo: PeriodoFiltro.rango,
                    desde: DateTime(2026, 1, 1),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Menos filtros'), findsOneWidget);
    expect(find.text('Hasta'), findsOneWidget);

    await tester.tap(find.text('Menos filtros'));
    await tester.pump();
    expect(find.text('Más filtros (2)'), findsOneWidget);

    await tester.tap(find.text('Más filtros (2)'));
    await tester.pump();
    expect(find.text('Menos filtros'), findsOneWidget);
    expect(find.text('Gasto'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);

    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(find.text('Todas'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rango de fechas'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    expect(find.text('Elige las dos fechas del rango'), findsOneWidget);

    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(resultado, isNotNull);
    expect(resultado!.categoria, isNull);
    expect(resultado!.tipo, isNull);
    expect(resultado!.periodo, isNull);
  });
}
