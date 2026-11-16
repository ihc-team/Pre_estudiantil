import 'servicio_acceso.dart';
import 'servicio_movimientos.dart';

class ServicioCuenta {
  static Future<Map<String, dynamic>> exportar() async {
    final token = await ServicioAcceso.obtenerToken();
    if (token == null) throw SesionExpirada();

    final respuesta = await ServicioAcceso.llamar(
      'GET',
      '/cuenta/exportar',
      token: token,
    );
    if (respuesta.statusCode == 401) throw SesionExpirada();

    return ServicioAcceso.leer(respuesta);
  }

  static Future<void> eliminar(String contrasena) async {
    final token = await ServicioAcceso.obtenerToken();
    if (token == null) throw SesionExpirada();

    final respuesta = await ServicioAcceso.llamar(
      'DELETE',
      '/cuenta',
      datos: {'contrasena': contrasena},
      token: token,
    );
    if (respuesta.statusCode == 401) throw SesionExpirada();

    ServicioAcceso.leer(respuesta);
    await ServicioAcceso.limpiarSesion();
  }
}
