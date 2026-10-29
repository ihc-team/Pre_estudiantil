/// Es el estado del presupuesto de una categoria en un mes
/// esto corresponde a cada item de ""categorias" en GET presupuestos-categoria
class PresupuestoCategoria {
  final String categoria;
  final double? limite;
  final double gastado;
  final double? restante;
  final double? proporcion;

  const PresupuestoCategoria({
    required this.categoria,
    required this.limite,
    required this.gastado,
    required this.restante,
    required this.proporcion,
  });

  factory PresupuestoCategoria.desdeJson(Map<String, dynamic> json) {
    return PresupuestoCategoria(
      categoria: json['categoria'] as String,
      limite: (json['limite'] as num?)?.toDouble(),
      gastado: (json['gastado'] as num).toDouble(),
      restante: (json['restante'] as num?)?.toDouble(),
      proporcion: (json['proporcion'] as num?)?.toDouble(),
    );
  }

  bool get tieneLimite => limite != null;

  /// Lanza un alerta amarilla si se supera el 80 %
  bool get enAviso => tieneLimite && gastado > limite! * 0.8;

  /// lanza alerta roja si se supera el 100 %
  bool get excedido => tieneLimite && gastado > limite!;
}
