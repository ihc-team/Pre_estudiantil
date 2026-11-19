import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/evento.dart';
import 'package:ihcpre_estudiantil2/modelos/filtros.dart';
import 'package:ihcpre_estudiantil2/modelos/movimiento.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_acceso.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_analitica.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_cuenta.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_historial.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_limite.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_metas.dart';
import 'package:ihcpre_estudiantil2/servicios/servicio_movimientos.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _movimiento = {
  'id': 1,
  'concepto': 'Almuerzo',
  'monto': 15,
  'fecha': '2026-11-01',
  'tipo': 'gasto',
  'categoria': 'comida',
  'estado': 'pendiente',
  'recurrente': false,
  'frecuencia': null,
};

const _resumenMetas = {'total': 100.0, 'reservado': 20.0, 'disponible': 80.0};
const _meta = {
  'id': 1,
  'nombre': 'Viaje',
  'montoObjetivo': 100.0,
  'montoReservado': 20.0,
  'fechaObjetivo': '2026-12-01',
  'progreso': 0.2,
};
const _resumenLimite = {
  'mes': '2026-11',
  'limite': 1000.0,
  'gastado': 200.0,
  'restante': 800.0,
};
const _categoria = {
  'categoria': 'comida',
  'limite': 500.0,
  'gastado': 100.0,
  'restante': 400.0,
  'proporcion': 0.2,
};

late HttpServer server;
late String baseUrl;

Future<void> _responder(HttpRequest request, Object cuerpo, [int estado = 200]) async {
  request.response.statusCode = estado;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(cuerpo));
  await request.response.close();
}

void main() {
  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    dotenv.loadFromString(envString: 'API_BASE_URL=$baseUrl');

    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      final path = request.uri.path;
      final auth = request.headers.value(HttpHeaders.authorizationHeader);

      if (auth == 'Bearer invalido' && path != '/login') {
        await _responder(request, {'error': 'Sesión expirada'}, 401);
        return;
      }

      switch ((request.method, path)) {
        case ('POST', '/registro'):
          await _responder(request, {});
        case ('POST', '/login'):
          await _responder(request, {'token': 'token-1'});
        case ('GET', '/perfil'):
          await _responder(request, {'nombre': 'Ana Torres'});
        case ('POST', '/logout'):
          await _responder(request, {});
        case ('POST', '/recuperar'):
          await _responder(request, {'codigo': '123456'});
        case ('POST', '/cambiar-contrasena'):
          await _responder(request, {});
        case ('GET', '/movimientos'):
          await _responder(request, {
            'movimientos': [_movimiento],
            'totales': {'cantidad': 1, 'ingresos': 0.0, 'gastos': 15.0},
          });
        case ('POST', '/movimientos'):
          await _responder(request, {'movimiento': _movimiento});
        case ('POST', '/movimientos/1/pagar'):
          await _responder(request, {
            'movimiento': {..._movimiento, 'estado': 'pagado'},
          });
        case ('PUT', '/movimientos/1'):
          await _responder(request, {'movimiento': _movimiento});
        case ('DELETE', '/movimientos/1'):
          await _responder(request, {});
        case ('GET', '/historial'):
          await _responder(request, {
            'grupos': [
              {
                'titulo': 'Hoy',
                'eventos': [
                  {
                    'id': 1,
                    'tipo': 'gasto_registrado',
                    'monto': 15.0,
                    'descripcion': 'Almuerzo',
                    'movimientoId': 1,
                    'hora': '12:00',
                    'creadoEn': '2026-11-01T12:00:00.000Z',
                  },
                ],
              },
            ],
          });
        case ('GET', '/metas'):
          await _responder(request, {
            'metas': [_meta],
            'resumen': _resumenMetas,
          });
        case ('POST', '/metas'):
          await _responder(request, {'meta': _meta, 'resumen': _resumenMetas});
        case ('POST', '/metas/1/asignar'):
          await _responder(request, {'meta': _meta, 'resumen': _resumenMetas});
        case ('POST', '/metas/1/retirar'):
          await _responder(request, {'meta': _meta, 'resumen': _resumenMetas});
        case ('POST', '/metas/1/transferir'):
          await _responder(request, {'meta': _meta, 'resumen': _resumenMetas});
        case ('GET', '/metas/1/movimientos'):
          await _responder(request, {
            'movimientos': [
              {
                'id': 1,
                'tipo': 'asignacion',
                'monto': 20.0,
                'metaRelacionada': 'Viaje',
                'creadoEn': '2026-11-01T12:00:00.000Z',
              },
            ],
          });
        case ('GET', '/limite'):
          await _responder(request, _resumenLimite);
        case ('PUT', '/limite'):
          await _responder(request, _resumenLimite);
        case ('GET', '/presupuestos-categoria'):
          await _responder(request, {
            'categorias': [_categoria],
          });
        case ('PUT', '/presupuestos-categoria'):
          await _responder(request, {});
        case ('GET', '/cuenta/exportar'):
          await _responder(request, {'movimientos': []});
        case ('DELETE', '/cuenta'):
          await _responder(request, {});
        case ('POST', '/analitica/eventos'):
          await _responder(request, {});
        default:
          await _responder(request, {'error': 'No encontrado'}, 404);
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'token-1'});
  });

  group('ServicioAcceso', () {
    test('registra y lee respuestas correctas', () async {
      await ServicioAcceso.registrar('Ana', 'ana@correo.com', '123456');
      final datos = ServicioAcceso.leer(
        await ServicioAcceso.llamar('GET', '/perfil'),
      );
      expect(datos['nombre'], 'Ana Torres');
    });

    test('guarda el token al iniciar sesión', () async {
      SharedPreferences.setMockInitialValues({});
      await ServicioAcceso.iniciarSesion('ana@correo.com', '123456');
      expect(await ServicioAcceso.obtenerToken(), 'token-1');
    });

    test('lee la sesión y limpia tokens inválidos', () async {
      expect(await ServicioAcceso.obtenerNombreSesion(), 'Ana Torres');

      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      expect(await ServicioAcceso.obtenerNombreSesion(), isNull);
      expect(await ServicioAcceso.obtenerToken(), isNull);
    });

    test('sin token no consulta la sesión', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ServicioAcceso.obtenerNombreSesion(), isNull);
    });

    test('cierra sesión y tolera falta de token', () async {
      await ServicioAcceso.cerrarSesion();
      expect(await ServicioAcceso.obtenerToken(), isNull);

      SharedPreferences.setMockInitialValues({});
      await ServicioAcceso.cerrarSesion();
      await ServicioAcceso.limpiarSesion();
    });

    test('recupera y cambia la contraseña', () async {
      expect(await ServicioAcceso.pedirCodigo('ana@correo.com'), '123456');
      await ServicioAcceso.cambiarContrasena(
        'ana@correo.com',
        '123456',
        'nueva123',
      );
    });

    test('lanza ErrorAcceso con el mensaje del servidor', () async {
      final respuesta = await ServicioAcceso.llamar('GET', '/ruta-inexistente');
      expect(
        () => ServicioAcceso.leer(respuesta),
        throwsA(
          isA<ErrorAcceso>().having((e) => e.mensaje, 'mensaje', 'No encontrado'),
        ),
      );
    });

    test('ErrorAcceso por falta de conexión', () async {
      final anterior = dotenv.env['API_BASE_URL'];
      dotenv.env['API_BASE_URL'] = 'http://127.0.0.1:1';
      await expectLater(
        ServicioAcceso.llamar('GET', '/perfil'),
        throwsA(isA<ErrorAcceso>()),
      );
      dotenv.env['API_BASE_URL'] = anterior ?? baseUrl;
    });

    test('soporta PUT y DELETE con cuerpo', () async {
      final put = await ServicioAcceso.llamar(
        'PUT',
        '/ruta-inexistente',
        datos: {'x': 1},
      );
      final delete = await ServicioAcceso.llamar(
        'DELETE',
        '/ruta-inexistente',
        datos: {'x': 1},
      );
      expect(put.statusCode, 404);
      expect(delete.statusCode, 404);
    });
  });

  group('ServicioMovimientos', () {
    test('lista movimientos y totales', () async {
      final resultado = await ServicioMovimientos.listar();
      expect(resultado.movimientos.single.concepto, 'Almuerzo');
      expect(resultado.totales.gastos, 15);
    });

    test('lista con filtros y sin token', () async {
      await ServicioMovimientos.listar(
        const FiltrosMovimientos(buscar: 'almuerzo'),
      );
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        ServicioMovimientos.listar(),
        throwsA(isA<SesionExpirada>()),
      );
    });

    test('crea, edita, paga y elimina', () async {
      final creado = await ServicioMovimientos.crear(
        'Almuerzo',
        15,
        DateTime(2026, 11, 1),
        TipoMovimiento.gasto,
        CategoriaMovimiento.comida,
        recurrente: true,
        frecuencia: FrecuenciaRecurrencia.mensual,
      );
      expect(creado.id, 1);

      final editado = await ServicioMovimientos.editar(
        creado,
        'Cena',
        20,
        DateTime(2026, 11, 2),
        CategoriaMovimiento.otros,
      );
      expect(editado.concepto, 'Almuerzo');

      final pagado = await ServicioMovimientos.marcarComoPagado(creado);
      expect(pagado.estado, EstadoMovimiento.pagado);

      await ServicioMovimientos.eliminar(creado);
    });

    test('propaga sesión expirada del servidor', () async {
      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      await expectLater(
        ServicioMovimientos.listar(),
        throwsA(isA<SesionExpirada>()),
      );
    });
  });

  group('ServicioMetas', () {
    test('lista, crea y opera fondos', () async {
      final listado = await ServicioMetas.listar();
      expect(listado.metas.single.nombre, 'Viaje');

      final creada = await ServicioMetas.crear(
        'Viaje',
        100,
        DateTime(2026, 12, 1),
      );
      expect(creada.meta.id, 1);

      expect((await ServicioMetas.asignar(1, 20)).resumen.total, 100);
      expect((await ServicioMetas.retirar(1, 5)).meta.nombre, 'Viaje');
      expect((await ServicioMetas.transferir(1, 2, 5)).meta.id, 1);
      expect((await ServicioMetas.historial(1)).single.tipo, 'asignacion');
    });

    test('sin token y token inválido', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        ServicioMetas.listar(),
        throwsA(isA<SesionExpirada>()),
      );
      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      await expectLater(
        ServicioMetas.listar(),
        throwsA(isA<SesionExpirada>()),
      );
    });
  });

  group('ServicioLimite', () {
    test('lee, guarda y consulta por categoría', () async {
      expect((await ServicioLimite.leer()).limite, 1000);
      expect((await ServicioLimite.leer('2026-11')).restante, 800);
      expect((await ServicioLimite.guardar('1000,50')).gastado, 200);
      expect((await ServicioLimite.leerPorCategoria()).single.categoria, 'comida');
      expect(
        (await ServicioLimite.leerPorCategoria('2026-11')).single.limite,
        500,
      );
      await ServicioLimite.guardarPorCategoria(
        categoria: 'comida',
        montoTexto: '500',
      );
      await ServicioLimite.guardarPorCategoria(
        categoria: 'comida',
        montoTexto: '500',
        mes: '2026-11',
      );
    });

    test('valida montos antes de llamar al servidor', () async {
      expect(() => ServicioLimite.guardar(''), throwsStateError);
      await expectLater(
        ServicioLimite.guardarPorCategoria(
          categoria: 'comida',
          montoTexto: '0',
        ),
        throwsException,
      );
    });

    test('sin token y token inválido', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        ServicioLimite.leer(),
        throwsA(isA<SesionExpirada>()),
      );
      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      await expectLater(
        ServicioLimite.leer(),
        throwsA(isA<SesionExpirada>()),
      );
    });
  });

  group('ServicioHistorial', () {
    test('lista grupos y filtra por tipo', () async {
      final grupos = await ServicioHistorial.listar(
        filtro: FiltroHistorial.gastos,
      );
      expect(grupos.single.titulo, 'Hoy');
      expect(grupos.single.eventos.single.descripcion, 'Almuerzo');
    });

    test('sin token y token inválido', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        ServicioHistorial.listar(),
        throwsA(isA<SesionExpirada>()),
      );
      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      await expectLater(
        ServicioHistorial.listar(),
        throwsA(isA<SesionExpirada>()),
      );
    });
  });

  group('ServicioCuenta', () {
    test('exporta y elimina', () async {
      expect(await ServicioCuenta.exportar(), containsPair('movimientos', []));
      await ServicioCuenta.eliminar('123456');
      expect(await ServicioAcceso.obtenerToken(), isNull);
    });

    test('sin token y token inválido', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(
        ServicioCuenta.exportar(),
        throwsA(isA<SesionExpirada>()),
      );
      await expectLater(
        ServicioCuenta.eliminar('123456'),
        throwsA(isA<SesionExpirada>()),
      );
      SharedPreferences.setMockInitialValues({'token': 'invalido'});
      await expectLater(
        ServicioCuenta.exportar(),
        throwsA(isA<SesionExpirada>()),
      );
      await expectLater(
        ServicioCuenta.eliminar('123456'),
        throwsA(isA<SesionExpirada>()),
      );
    });
  });

  group('ServicioAnalitica', () {
    test('envía eventos con sesión y falla en silencio sin ella', () async {
      await ServicioAnalitica.track('evento', {'x': 1});
      SharedPreferences.setMockInitialValues({});
      await ServicioAnalitica.track('evento', {'x': 1});
    });
  });
}
