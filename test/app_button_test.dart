import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/configuracion/tema/app_tokens.dart';
import 'package:ihcpre_estudiantil2/widgets/app_button.dart';

void main() {
  group('AppButton - Pruebas de Componente y Estados', () {
    testWidgets('renderiza texto e iconos correctamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Continuar',
              leadingIcon: Icons.check,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Continuar'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('ejecuta onPressed al ser presionado en estado normal', (
      tester,
    ) async {
      bool presionado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'Click', onPressed: () => presionado = true),
          ),
        ),
      );

      await tester.tap(find.text('Click'));
      await tester.pump();

      expect(presionado, isTrue);
    });

    testWidgets(
      'no ejecuta callback en estado deshabilitado (onPressed == null)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AppButton(label: 'Deshabilitado', onPressed: null),
            ),
          ),
        );

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.onTap, isNull);
      },
    );

    testWidgets('muestra indicador de carga y bloquea tap en estado loading', (
      tester,
    ) async {
      bool presionado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Cargando',
              isLoading: true,
              onPressed: () => presionado = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cargando'), findsNothing);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
      expect(presionado, isFalse);
    });

    testWidgets('cumple con el area táctil mínima de accesibilidad (>= 48dp)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Accesible',
              size: AppButtonSize.medium,
              onPressed: () {},
            ),
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(AppButton));
      expect(size.height, greaterThanOrEqualTo(AppSizes.touchTargetMin));
    });
  });
}
