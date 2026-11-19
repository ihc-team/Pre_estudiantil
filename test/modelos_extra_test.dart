import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ihcpre_estudiantil2/modelos/evento.dart';
import 'package:ihcpre_estudiantil2/modelos/filtros.dart';
import 'package:ihcpre_estudiantil2/modelos/meta_ahorro.dart';
import 'package:ihcpre_estudiantil2/modelos/movimiento.dart';
import 'package:ihcpre_estudiantil2/modelos/presupuesto_categoria.dart';

void main() {
  group('Movimiento', () {
    test('desdeJson interpreta una respuesta completa', () {
      final movimiento = Movimiento.desdeJson({
        'id': 7,
        'concepto': 'Almuerzo',
        'monto': 25,
        'fecha': '2026-11-19',
        'tipo': 'ingreso',
        'categoria': 'comida',
        'estado': 'pagado',
        'recurrente': true,
        'frecuencia': 'semanal',
      });

      expect(movimiento.esIngreso, isTrue);
      expect(movimiento.recurrente, isTrue);
      expect(movimiento.recurrenciaTexto, 'Recurrente Semanal');
      expect(movimiento.estadoTexto, 'Cobrado');
      expect(movimiento.accionMarcarTexto, 'Marcar como cobrado');
      expect(movimiento.montoTexto, contains('25,00'));
      expect(movimiento.fechaTexto, '19/11/2026');
    });

    test('desdeJson usa valores por defecto', () {
      final movimiento = Movimiento.desdeJson({
        'id': 1,
        'concepto': 'Gasto',
        'monto': 10,
        'fecha': '2026-11-19',
      });

      expect(movimiento.tipo, TipoMovimiento.gasto);
      expect(movimiento.categoria, CategoriaMovimiento.otros);
      expect(movimiento.estado, EstadoMovimiento.pendiente);
      expect(movimiento.frecuencia, isNull);
      expect(movimiento.recurrenciaTexto, 'Recurrente');
      expect(movimiento.estadoTexto, 'Pendiente');
      expect(movimiento.accionMarcarTexto, 'Marcar como pagado');
      expect(movimiento.motivoMontoBloqueadoTexto, contains('pagado'));
    });

    test('marcarComoPagado cambia el estado y conserva datos', () {
      final movimiento = Movimiento(
        id: 2,
        concepto: 'Transporte',
        monto: 5,
        fecha: DateTime(2026, 11, 19),
        categoria: CategoriaMovimiento.transporte,
      );
      final pagado = movimiento.marcarComoPagado();

      expect(pagado.estado, EstadoMovimiento.pagado);
      expect(pagado.montoBloqueado, isTrue);
      expect(pagado.id, movimiento.id);
      expect(pagado.categoria, movimiento.categoria);
      expect(pagado.frecuencia, isNull);
    });

    test('marcarComoPagado rechaza un gasto ya pagado', () {
      final movimiento = Movimiento(
        id: 3,
        concepto: 'Comida',
        monto: 10,
        fecha: DateTime(2026, 11, 19),
        estado: EstadoMovimiento.pagado,
      );

      expect(movimiento.marcarComoPagado, throwsStateError);
    });
  });

  group('Categorías y estados', () {
    test('textos de categorías', () {
      expect(CategoriaMovimiento.comida.texto, 'Comida');
      expect(CategoriaMovimiento.transporte.texto, 'Transporte');
      expect(CategoriaMovimiento.estudio.texto, 'Estudio');
      expect(CategoriaMovimiento.otros.texto, 'Otros');
      expect(TipoMovimiento.ingreso.texto, 'Ingreso');
      expect(TipoMovimiento.gasto.texto, 'Gasto');
      expect(EstadoMovimiento.pendiente.texto, 'Pendiente');
      expect(EstadoMovimiento.pagado.texto, 'Pagado');
      expect(FrecuenciaRecurrencia.semanal.texto, 'Semanal');
      expect(FrecuenciaRecurrencia.mensual.texto, 'Mensual');
    });
  });

  group('FiltrosMovimientos', () {
    test('construye parámetros, chips y limpia filtros', () {
      final filtros = FiltrosMovimientos.vacio
          .conBuscar('  comida ')
          .quitar(ClaveFiltro.buscar)
          .conBuscar('transporte');

      expect(filtros.hayFiltros, isTrue);
      expect(filtros.activos.first.texto, 'Búsqueda: "transporte"');
      expect(filtros.toQuery(), {'buscar': 'transporte'});
      expect(filtros.validar(), isNull);

      final conTodo = FiltrosMovimientos(
        buscar: 'x',
        tipo: TipoMovimiento.gasto,
        categoria: CategoriaMovimiento.comida,
        estado: EstadoMovimiento.pagado,
        periodo: PeriodoFiltro.rango,
        desde: DateTime(2026, 11, 1),
        hasta: DateTime(2026, 11, 30),
      );
      expect(conTodo.activos, hasLength(5));
      expect(conTodo.toQuery()['periodo'], 'rango');
      expect(conTodo.toQuery()['desde'], '2026-11-01');
      expect(conTodo.toQuery()['hasta'], '2026-11-30');
      expect(conTodo.quitar(ClaveFiltro.periodo).periodo, isNull);
    });

    test('valida el rango', () {
      final incompleto = FiltrosMovimientos(
        periodo: PeriodoFiltro.rango,
        desde: DateTime(2026, 11, 1),
      );
      expect(incompleto.validar(), mensajeRangoIncompleto);

      final invertido = FiltrosMovimientos(
        periodo: PeriodoFiltro.rango,
        desde: DateTime(2026, 11, 2),
        hasta: DateTime(2026, 11, 1),
      );
      expect(invertido.validar(), mensajeRangoInvertido);
    });
  });

  group('PresupuestoCategoria', () {
    test('interpreta límites y estados', () {
      final sinLimite = PresupuestoCategoria.desdeJson({
        'categoria': 'Comida',
        'limite': null,
        'gastado': 10,
        'restante': null,
        'proporcion': null,
      });
      expect(sinLimite.tieneLimite, isFalse);
      expect(sinLimite.estado, EstadoPresupuesto.sinLimite);
      expect(sinLimite.progresoBarra, 0);
      expect(sinLimite.porcentajeTexto, '');
      expect(sinLimite.nombreLegible, 'Comida');
      expect(sinLimite.icono, Icons.restaurant);

      final excedido = PresupuestoCategoria.desdeJson({
        'categoria': 'transporte',
        'limite': 100,
        'gastado': 120,
        'restante': -20,
        'proporcion': 1.2,
      });
      expect(excedido.estado, EstadoPresupuesto.excedido);
      expect(excedido.progresoBarra, 1);
      expect(excedido.porcentajeTexto, '120%');
      expect(excedido.icono, Icons.directions_bus);

      final aviso = PresupuestoCategoria.desdeJson({
        'categoria': 'estudio',
        'limite': 100,
        'gastado': 80,
        'restante': 20,
        'proporcion': 0.8,
      });
      expect(aviso.estado, EstadoPresupuesto.aviso);
      expect(aviso.icono, Icons.school);
      expect(aviso.estado, isNot(EstadoPresupuesto.normal));
    });
  });

  group('Metas y eventos', () {
    test('MetaAhorro calcula restante y textos', () {
      final meta = MetaAhorro.desdeJson({
        'id': 1,
        'nombre': 'Viaje',
        'montoObjetivo': 500,
        'montoReservado': 200,
        'fechaObjetivo': '2027-02-01',
        'progreso': 0.4,
      });
      expect(meta.restante, 300);
      expect(meta.montoObjetivoTexto, contains('500,00'));
      expect(meta.montoReservadoTexto, contains('200,00'));
      expect(meta.restanteTexto, contains('300,00'));
      expect(meta.fechaTexto, '01/02/2027');

      final excedida = MetaAhorro.desdeJson({
        'id': 2,
        'nombre': 'Curso',
        'montoObjetivo': 100,
        'montoReservado': 150,
        'fechaObjetivo': '2027-02-01',
        'progreso': 1,
      });
      expect(excedida.restante, 0);
    });

    test('ResumenMetas y MovimientoMeta', () {
      final resumen = ResumenMetas.desdeJson({
        'total': 1000,
        'reservado': 200,
        'disponible': 800,
      });
      expect(resumen.totalTexto, contains('1000,00'));
      expect(resumen.reservadoTexto, contains('200,00'));
      expect(resumen.disponibleTexto, contains('800,00'));

      final movimiento = MovimientoMeta.desdeJson({
        'id': 3,
        'tipo': 'transferencia_entrada',
        'monto': 50,
        'metaRelacionada': 'Viaje',
        'creadoEn': '2026-11-19T10:30:00.000Z',
      });
      expect(movimiento.tipoTexto, 'Transferencia recibida');
      expect(movimiento.montoTexto, contains('50,00'));
      expect(movimiento.fechaTexto, isNotEmpty);
    });

    test('eventos y filtros del historial', () {
      expect(TipoEvento.gastoRegistrado.textoServidor, 'gasto_registrado');
      expect(TipoEvento.ingresoRegistrado.textoServidor, 'ingreso_registrado');
      expect(TipoEvento.movimientoPagado.textoServidor, 'movimiento_pagado');
      expect(TipoEvento.limiteDefinido.textoServidor, 'limite_definido');
      expect(TipoEvento.desdeTexto('gasto_registrado'), TipoEvento.gastoRegistrado);
      expect(() => TipoEvento.desdeTexto('otro'), throwsArgumentError);

      expect(FiltroHistorial.todos.etiqueta, 'Todos');
      expect(FiltroHistorial.gastos.etiqueta, 'Gastos');
      expect(FiltroHistorial.ingresos.etiqueta, 'Ingresos');
      expect(FiltroHistorial.pagos.etiqueta, 'Pagos');
      expect(FiltroHistorial.limite.etiqueta, 'Límite');
      expect(FiltroHistorial.todos.textoServidor, 'todos');

      final evento = Evento.desdeJson({
        'id': 1,
        'tipo': 'gasto_registrado',
        'monto': 20,
        'descripcion': 'Comida',
        'movimientoId': 4,
        'hora': '10:30',
        'creadoEn': '2026-11-19T10:30:00.000Z',
      });
      expect(evento.descripcion, 'Comida');
      expect(evento.monto, 20);
      expect(evento.movimientoId, 4);

      final grupo = GrupoDia.desdeJson({
        'titulo': 'Hoy',
        'eventos': [
          {
            'id': 1,
            'tipo': 'gasto_registrado',
            'monto': 20,
            'descripcion': 'Comida',
            'movimientoId': 4,
            'hora': '10:30',
            'creadoEn': '2026-11-19T10:30:00.000Z',
          },
        ],
      });
      expect(grupo.titulo, 'Hoy');
      expect(grupo.eventos, hasLength(1));
    });
  });
}

