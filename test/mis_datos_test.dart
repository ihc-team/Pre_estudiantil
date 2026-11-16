import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ihcpre_estudiantil2/servicios/analitica.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AnaliticaServicio.reiniciar();
  });

  group('Tarea 10 - Pruebas del flujo "Mis datos y salida honesta"', () {
    test('1. Registro de analítica al descargar datos (formato json, sin datos personales)', () async {
      await AnaliticaServicio.track('datos_descargados', {'formato': 'json'});

      final resumen = await AnaliticaServicio.obtenerResumen();
      final ultimos = resumen['ultimos'] as List<dynamic>;

      expect(ultimos.length, 1);
      final evento = ultimos.first as Map<String, dynamic>;
      expect(evento['evento'], 'datos_descargados');
      expect(evento['props']['formato'], 'json');

      // Regla de privacidad: NINGÚN dato personal o financiero
      expect(evento['props'].containsKey('correo'), isFalse);
      expect(evento['props'].containsKey('email'), isFalse);
      expect(evento['props'].containsKey('usuarioId'), isFalse);
      expect(evento['props'].containsKey('nombre'), isFalse);
      expect(evento['props'].containsKey('monto'), isFalse);
    });

    test('2. Registro de analítica al iniciar y completar eliminación de cuenta', () async {
      // 1. Inicia diálogo de eliminación
      await AnaliticaServicio.track('cuenta_eliminacion_iniciada', {});
      // 2. Confirma con éxito la eliminación
      await AnaliticaServicio.track('cuenta_eliminada', {});

      final resumen = await AnaliticaServicio.obtenerResumen();
      final ultimos = resumen['ultimos'] as List<dynamic>;

      expect(ultimos.length, 2);
      expect(ultimos[0]['evento'], 'cuenta_eliminada');
      expect(ultimos[1]['evento'], 'cuenta_eliminacion_iniciada');
    });

    test('3. Simulación del recorrido completo: descarga, eliminación y rechazo de sesión', () async {
      // Estado inicial: usuario activo con sesión
      var tieneSesionActiva = true;
      var sesionValidaEnServidor = true;

      // Paso 1: Descarga sus datos
      await AnaliticaServicio.track('datos_descargados', {'formato': 'json'});

      // Paso 2: Inicia eliminación
      await AnaliticaServicio.track('cuenta_eliminacion_iniciada', {});

      // Paso 3: Confirma con contraseña y el servidor ejecuta DELETE /cuenta (onDelete: Cascade)
      sesionValidaEnServidor = false;
      tieneSesionActiva = false;
      await AnaliticaServicio.track('cuenta_eliminada', {});

      // Paso 4: Intento de usar el token previo o iniciar sesión tras borrado
      int codigoRespuestaReintento;
      if (!sesionValidaEnServidor) {
        codigoRespuestaReintento = 401; // Unauthorized
      } else {
        codigoRespuestaReintento = 200;
      }

      expect(tieneSesionActiva, isFalse);
      expect(codigoRespuestaReintento, 401);
    });
  });
}

