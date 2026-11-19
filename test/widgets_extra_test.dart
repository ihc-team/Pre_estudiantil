import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/meta_ahorro.dart';
import 'package:ihcpre_estudiantil2/widgets/boton_pildora.dart';
import 'package:ihcpre_estudiantil2/widgets/campo_texto.dart';
import 'package:ihcpre_estudiantil2/widgets/fondo_decorativo.dart';
import 'package:ihcpre_estudiantil2/widgets/mensajes.dart';
import 'package:ihcpre_estudiantil2/widgets/resumen_metas_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('CampoTexto muestra etiqueta, error y alterna contraseña', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secreto');
    String? cambiado;

    await tester.pumpWidget(
      wrap(
        CampoTexto(
          controlador: controller,
          etiqueta: 'Contraseña',
          icono: Icons.lock,
          esContrasena: true,
          error: 'Completa este campo',
          pista: 'Tu clave',
          alCambiar: (valor) => cambiado = valor,
        ),
      ),
    );

    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Completa este campo'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nueva');
    expect(cambiado, 'nueva');
  });

  testWidgets('CampoTexto respeta deshabilitado y solo lectura', (tester) async {
    final controller = TextEditingController(text: 'fijo');
    await tester.pumpWidget(
      wrap(
        CampoTexto(
          controlador: controller,
          etiqueta: 'Solo lectura',
          icono: Icons.lock,
          habilitado: false,
          soloLectura: true,
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(field.readOnly, isTrue);
  });

  testWidgets('BotonPildora ejecuta la acción y usa variante secundaria', (
    tester,
  ) async {
    var tocado = 0;
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            BotonPildora(
              texto: 'Entrar',
              icono: Icons.login,
              alPresionar: () => tocado++,
            ),
            BotonPildora(
              texto: 'Cancelar',
              icono: Icons.close,
              esRelleno: false,
              alPresionar: () => tocado++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Entrar'));
    await tester.tap(find.text('Cancelar'));
    expect(tocado, 2);
  });

  testWidgets('ResumenMetasCard muestra los tres saldos', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ResumenMetasCard(
          resumen: ResumenMetas(
            total: 1000,
            reservado: 200,
            disponible: 800,
          ),
        ),
      ),
    );

    expect(find.text('Saldos'), findsOneWidget);
    expect(find.textContaining('Total'), findsOneWidget);
    expect(find.textContaining('Reservado'), findsOneWidget);
    expect(find.textContaining('Disponible'), findsOneWidget);
  });

  testWidgets('mostrarMensaje muestra un SnackBar de error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarMensaje(
                context,
                'Falló',
                esError: true,
              ),
              child: const Text('Mostrar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    expect(find.text('Falló'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('FondoDecorativo se pinta sin errores', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            child: FondoDecorativo(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FondoDecorativo), findsOneWidget);
  });
}
