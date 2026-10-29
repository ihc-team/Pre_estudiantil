import 'package:flutter/material.dart';

import '../configuracion/constantes.dart';
import '../configuracion/rutas.dart';
import '../modelos/limite.dart';
import '../servicios/servicio_acceso.dart';
import '../servicios/servicio_limite.dart';
import '../servicios/servicio_movimientos.dart';
import '../widgets/boton_pildora.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensajes.dart';
import '../modelos/presupuesto_categoria.dart';

class PantallaLimite extends StatefulWidget {
  const PantallaLimite({super.key});

  @override
  State<PantallaLimite> createState() => _PantallaLimiteState();
}

class _PantallaLimiteState extends State<PantallaLimite> {
  final _limite = TextEditingController();
  String? _errorLimite;
  bool _cargando = false;
  ResumenLimite? _resumen;
  // Lo que devolvió el servidor al guardar; mientras exista se muestra la confirmación
  ResumenLimite? _guardado;

  // tarea 5 presupuesto
  List<PresupuestoCategoria> _presupuestosCategorias = [];

  @override
  void initState() {
    super.initState();
    _cargarLimite();
  }

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  void _volverAlLogin() {
    Navigator.pushNamedAndRemoveUntil(context, Rutas.login, (ruta) => false);
  }

  // Al entrar se pide el limite a la base, asi se ve lo guardado aunque se cierre la app
  Future<void> _cargarLimite() async {
    try {
      final resumen = await ServicioLimite.leer();
      final categorias =
          await ServicioLimite.leerPorCategoria(); // <-- Nueva llamada
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _presupuestosCategorias = categorias; // <-- Guardamos la lista
        if (resumen.tieneLimite) {
          _limite.text = resumen.limite!.toStringAsFixed(2);
        }
      });
    } on SesionExpirada {
      if (!mounted) return;
      _volverAlLogin();
    } on ErrorAcceso catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, esError: true);
    }
  }

  Future<void> _editarPresupuesto(PresupuestoCategoria item) async {
    final controlador = TextEditingController(
      text: item.limite != null ? item.limite!.toStringAsFixed(2) : '',
    );

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Presupuesto para ${item.categoria.toUpperCase()}'),
        content: TextField(
          controller: controlador,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto (Bs)',
            hintText: 'Ej.: 200',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ServicioLimite.guardarPorCategoria(
                  categoria: item.categoria,
                  montoTexto: controlador.text,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (mounted) {
                  mostrarMensaje(context, e.toString(), esError: true);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado == true) {
      _cargarLimite(); // Recargamos para actualizar las tarjetas y consumos
    }
  }

  Future<void> _guardar() async {
    setState(() => _errorLimite = validarMontoLimite(_limite.text));
    if (_errorLimite != null) return;

    setState(() => _cargando = true);
    try {
      final guardado = await ServicioLimite.guardar(_limite.text);
      if (!mounted) return;
      // La pantalla no se cierra: la confirmación queda junto al botón
      setState(() => _guardado = guardado);
    } on SesionExpirada {
      if (!mounted) return;
      _volverAlLogin();
    } on ErrorAcceso catch (e) {
      // El error del servidor (por ejemplo, "Ya gastaste…") va debajo del campo
      if (!mounted) return;
      setState(() => _errorLimite = e.mensaje);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorLimite = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Confirmación de éxito junto al botón (clase 15, hallazgo 1)
  Widget _confirmacion(ResumenLimite r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colores.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colores.verdeOscuro),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textoConfirmacionLimite(r),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colores.verdeOscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Las reglas del límite, antes de que la persona las descubra con un bloqueo (H10.1)
  Widget _comoFunciona() {
    const reglas = [
      'Si un gasto supera el límite, no se guarda.',
      'Solo cuentan los gastos; los ingresos no.',
      'Es el límite de este mes y no puede ser menor a lo que ya gastaste.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colores.verdeClaro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colores.verdeOscuro),
              SizedBox(width: 8),
              Text(
                'Cómo funciona',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colores.azulOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final regla in reglas)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $regla',
                style: const TextStyle(color: Colores.grisAzulado, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colores.azulOscuro,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Límite del mes',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colores.azulOscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuánto quieres gastar como máximo este mes.',
                style: TextStyle(fontSize: 16, color: Colores.grisAzulado),
              ),
              // El límite no puede quedar por debajo de esto
              if (_resumen != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Este mes ya gastaste ${formatearBs(_resumen!.gastado)}.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colores.grisAzulado,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _comoFunciona(),
              const SizedBox(height: 32),
              CampoTexto(
                controlador: _limite,
                etiqueta: 'Límite del mes (Bs)',
                icono: Icons.savings_outlined,
                pista: 'Ej.: 500',
                tipoTeclado: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                error: _errorLimite,
                // Si cambia el monto, se oculta la confirmación y vuelve "Guardar límite"
                alCambiar: (_) => setState(() {
                  _errorLimite = null;
                  _guardado = null;
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 58,
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colores.verdeOscuro,
                        ),
                      )
                    : _guardado != null
                    ? BotonPildora(
                        // H4.4: check a la izquierda y la flecha de la derecha,
                        // igual que los demás botones (antes: ← y → opuestas)
                        texto: 'Listo',
                        icono: Icons.check,
                        alPresionar: () => Navigator.pop(context, true),
                      )
                    : BotonPildora(
                        texto: 'Guardar límite',
                        icono: Icons.check,
                        alPresionar: _guardar,
                      ),
              ),
              if (_guardado != null) ...[
                const SizedBox(height: 16),
                _confirmacion(_guardado!),
              ],
              const SizedBox(height: 24),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Presupuesto por categorias',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colores.azulOscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca una categoria para cambiar o definir su presupuesto:',
                style: TextStyle(fontSize: 14, color: Colores.grisAzulado),
              ),
              const SizedBox(height: 16),

              // Las tarjetas de cada categoría
              for (final item in _presupuestosCategorias)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      item.categoria.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Gastado: ${formatearBs(item.gastado)}'),
                        if (item.tieneLimite) ...[
                          Text('El Presupuesto: ${formatearBs(item.limite!)}'),
                          Text(
                            item.excedido
                                ? 'Se excedio por ${formatearBs(-item.restante!)}!'
                                : 'Quedan: ${formatearBs(item.restante!)}',
                            style: TextStyle(
                              color: item.excedido
                                  ? Colors.red
                                  : (item.enAviso
                                        ? Colors.orange
                                        : Colors.green),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          const Text(
                            'Sin presupuesto definido',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editarPresupuesto(item),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
