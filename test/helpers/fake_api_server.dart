import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

class ApiRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic> body;
  final String? authorization;

  const ApiRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
    required this.authorization,
  });
}

class ApiReply {
  final int status;
  final Object body;

  const ApiReply(this.body, [this.status = 200]);
}

class _PermitirHttp extends HttpOverrides {}

typedef ApiHandler = Future<ApiReply> Function(ApiRequest request);

class FakeApiServer {
  FakeApiServer._(this._server);

  final HttpServer _server;
  ApiHandler handler = (_) async => const ApiReply({});

  int get port => _server.port;

  static Future<FakeApiServer> start() async {
    HttpOverrides.global = _PermitirHttp();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = FakeApiServer._(server);
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}',
    );
    server.listen(api._procesar);
    return api;
  }

  Future<void> _procesar(HttpRequest request) async {
    final crudo = await utf8.decoder.bind(request).join();
    final cuerpo = crudo.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(crudo) as Map<String, dynamic>;
    final solicitud = ApiRequest(
      method: request.method,
      path: request.uri.path,
      query: request.uri.queryParameters,
      body: cuerpo,
      authorization: request.headers.value(HttpHeaders.authorizationHeader),
    );

    try {
      final respuesta = await handler(solicitud);
      request.response.statusCode = respuesta.status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(respuesta.body));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

Future<void> esperarHasta(
  WidgetTester tester,
  bool Function() condicion, {
  int intentos = 60,
}) async {
  for (var i = 0; i < intentos; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (condicion()) return;
  }
}
