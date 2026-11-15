import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ihcpre_estudiantil2/main.dart' as app;
import 'package:ihcpre_estudiantil2/servicios/servicio_acceso.dart';

const String _correoBase = 'juanperez';
const String _contrasena = '123456';

Future<void> _esperarTexto(
  WidgetTester tester,
  String texto, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(texto).evaluate().isNotEmpty) return;
  }
  fail('No apareció "$texto" en la pantalla.');
}

Future<void> _esperarSinTexto(
  WidgetTester tester,
  String texto, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fin = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(texto).evaluate().isEmpty) return;
  }
  fail('La pantalla con "$texto" no se cerró.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: Flujo completo de mis datos y salida honesta', (
    tester,
  ) async {
    // 0. Asegurar estado inicial limpio sin sesiones residuales de pruebas previas
    await ServicioAcceso.limpiarSesion();

    final correoUnico =
        '$_correoBase-${DateTime.now().millisecondsSinceEpoch}@gmail.com';

    app.main();
    await tester.pumpAndSettle();

    // 1. Esperar a que la pantalla de arranque decida el destino y muestre la pantalla de inicio
    await _esperarTexto(tester, 'Registrarse');
    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    await _esperarTexto(tester, 'Crear cuenta');

    // Llenar campos de registro
    final camposTexto = find.byType(TextField);
    await tester.enterText(camposTexto.at(0), 'Juan Perez');
    await tester.enterText(camposTexto.at(1), correoUnico);
    await tester.enterText(camposTexto.at(2), _contrasena);
    await tester.enterText(camposTexto.at(3), _contrasena);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    // 2. Iniciar sesión
    await _esperarTexto(tester, 'Iniciar sesión');
    final camposLogin = find.byType(TextField);
    await tester.enterText(camposLogin.at(0), correoUnico);
    await tester.enterText(camposLogin.at(1), _contrasena);
    await tester.pumpAndSettle();

    // En la pantalla de login el botón de envío dice "Entrar"
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // 3. Verificar que entra a Mis movimientos
    await _esperarTexto(tester, 'Mis movimientos');

    // 4. Abrir menú de Cuenta y navegar a Mis datos
    final botonMenu = find.byIcon(Icons.more_vert);
    expect(botonMenu, findsOneWidget);
    await tester.tap(botonMenu);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis datos'));
    await tester.pumpAndSettle();

    // 5. Verificar pantalla Mis datos y botón de descarga (esperando carga remota)
    await _esperarTexto(tester, 'Descargar mis datos (JSON)');
    expect(find.text('Descargar mis datos (JSON)'), findsOneWidget);

    // Tocar descargar mis datos
    await tester.tap(find.text('Descargar mis datos (JSON)'));
    await tester.pumpAndSettle();

    // El SnackBar verde de confirmación flota en el fondo y tapa el botón inferior.
    // Ocultamos el SnackBar y esperamos a que termine su animación para despejar la pantalla:
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 6. Iniciar eliminación honesta de cuenta (scrollear hasta el botón si está fuera de pantalla)
    final botonEliminarCuenta = find.text('Eliminar mi cuenta y datos');
    await tester.scrollUntilVisible(botonEliminarCuenta, 100.0);
    await tester.pumpAndSettle();
    expect(botonEliminarCuenta, findsOneWidget);
    await tester.tap(botonEliminarCuenta);
    await tester.pumpAndSettle();

    // 7. Diálogo de confirmación simétrica
    await _esperarTexto(tester, 'Eliminar cuenta y datos');
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);

    // Escribir contraseña en el diálogo
    final campoContrasena = find.byWidgetPredicate(
      (w) => w is TextField && w.obscureText == true,
    );
    await tester.enterText(campoContrasena, _contrasena);
    await tester.pumpAndSettle();

    // Confirmar eliminación
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    // 8. Verificar que la cuenta fue eliminada y volvió al Login
    await _esperarTexto(tester, 'Iniciar sesión');

    // 9. Reintentar login con la cuenta eliminada (debe fallar)
    final camposReintento = find.byType(TextField);
    await tester.enterText(camposReintento.at(0), correoUnico);
    await tester.enterText(camposReintento.at(1), _contrasena);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Esperar respuesta de la red y verificar que no entra a movimientos
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mis movimientos'), findsNothing);
  });
}
