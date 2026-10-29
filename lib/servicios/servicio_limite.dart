import '../modelos/limite.dart';
import 'servicio_acceso.dart';
import 'servicio_movimientos.dart';
import '../modelos/presupuesto_categoria.dart';

class ServicioLimite {
  // Llamada con el token de la sesión
  static Future<Map<String, dynamic>> _pedir(
    String metodo, {
    Map<String, dynamic>? datos,
    String ruta = '/limite',
  }) async {
    final token = await ServicioAcceso.obtenerToken();
    if (token == null) throw SesionExpirada();

    final respuesta = await ServicioAcceso.llamar(
      metodo,
      ruta,
      datos: datos,
      token: token,
    );
    if (respuesta.statusCode == 401) throw SesionExpirada();
    return ServicioAcceso.leer(respuesta);
  }

  // Límite, gastado y restante del mes (AAAA-MM; sin mes, el actual). limite null si no lo definió
  static Future<ResumenLimite> leer([String? mes]) async {
    final datos = await _pedir(
      'GET',
      ruta: mes == null ? '/limite' : '/limite?mes=$mes',
    );
    return ResumenLimite.desdeJson(datos);
  }

  // Primero la regla del modelo, después la API
  static Future<ResumenLimite> guardar(String texto) async {
    final error = validarMontoLimite(texto);
    if (error != null) throw StateError(error);
    final datos = await _pedir('PUT', datos: {'monto': leerLimite(texto)});
    return ResumenLimite.desdeJson(datos);
  }

  // Si no esta el mes, el backend usa por defecto el actual
  static Future<List<PresupuestoCategoria>> leerPorCategoria([
    String? mes,
  ]) async {
    final ruta = mes == null
        ? '/presupuestos-categoria'
        : '/presupuestos-categoria?mes=${Uri.encodeQueryComponent(mes)}';

    final respuesta = await _pedir('GET', ruta: ruta);

    final lista = respuesta['categorias'] as List<dynamic>;
    return lista
        .map((c) => PresupuestoCategoria.desdeJson(c as Map<String, dynamic>))
        .toList();
  }

  // Lanza el mensaje de error si el monto no es valido o si el backend tiene un error
  static Future<void> guardarPorCategoria({
    required String categoria,
    required String montoTexto,
    String? mes,
  }) async {
    // valida el monto
    final error = validarMontoLimite(montoTexto);
    if (error != null) {
      throw Exception(error);
    }

    //
    final monto = double.parse(montoTexto.trim().replaceAll(',', '.'));

    await _pedir(
      'PUT',
      ruta: '/presupuestos-categoria',
      datos: {
        'categoria': categoria,
        'monto': monto,
        if (mes != null) 'mes': mes,
      },
    );
  }
}
