import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/presupuesto_categoria.dart';

void main() {
  test('parseo desde JSON y propiedades basicas', () {
    final json = {
      'categoria': 'comida',
      'limite': 300,
      'gastado': 150.0,
      'restante': 150.0,
      'proporcion': 0.5,
    };

    final p = PresupuestoCategoria.desdeJson(json);

    expect(p.categoria, 'comida');
    expect(p.limite, 300.0);
    expect(p.gastado, 150.0);
    expect(p.restante, 150.0);
    expect(p.proporcion, 0.5);
    expect(p.tieneLimite, true);
    expect(p.enAviso, false);
    expect(p.excedido, false);
  });

  test('categoria sin presupuesto definido', () {
    final json = {
      'categoria': 'otros',
      'limite': null,
      'gastado': 50.0,
      'restante': null,
      'proporcion': null,
    };

    final p = PresupuestoCategoria.desdeJson(json);

    expect(p.tieneLimite, false);
    expect(p.enAviso, false);
    expect(p.excedido, false);
  });

  test('alerta cuando supera el 80 %', () {
    final p = PresupuestoCategoria.desdeJson({
      'categoria': 'transporte',
      'limite': 100.0,
      'gastado': 85.0,
      'restante': 15.0,
      'proporcion': 0.85,
    });

    expect(p.enAviso, true);
    expect(p.excedido, false);
  });

  test('alerta cuando supera el 100 %', () {
    final p = PresupuestoCategoria.desdeJson({
      'categoria': 'transporte',
      'limite': 100.0,
      'gastado': 160.0,
      'restante': -60.0,
      'proporcion': 1.6,
    });

    expect(p.enAviso, true);
    expect(p.excedido, true);
  });
}
