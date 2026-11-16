const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { Prisma } = require('@prisma/client');
const prisma = require('./conexion');
const { puerto } = require('./env');

const {
  validarMontoLimite,
  validarLimiteContraGastado,
  puedeRegistrarGasto,
  calcularResumen
} = require('./limite');

const {
  TIPOS,
  CATEGORIAS,
  leerFiltros,
  filtrarMovimientos,
  calcularTotales,
  hoyTexto
} = require('./filtros');

const { validarCorreo } = require('./correo');
const { FILTROS: FILTROS_HISTORIAL, armarHistorial } = require('./historial');
const { FRECUENCIAS, sumarFrecuencia } = require('./recurrentes');
const {
  validarMontoMeta,
  validarNombreMeta,
  validarFechaMeta,
  calcularSaldos,
  validarAsignacion,
  validarRetiro,
  validarTransferencia,
} = require('./metas');
const { EVENTOS, fechaBolivia, validarEvento } = require('./analitica');

const app = express();
app.use(cors());
app.use(express.json());

// Las fechas DATE se manejan como 'AAAA-MM-DD' para evitar problemas de zona horaria
function fechaATexto(fecha) {
  return fecha.toISOString().slice(0, 10);
}

function textoAFecha(texto) {
  return new Date(`${texto}T00:00:00.000Z`);
}

function formatearMovimiento(movimiento) {
  return {
    id: movimiento.id,
    concepto: movimiento.concepto,
    monto: Number(movimiento.monto),
    fecha: fechaATexto(movimiento.fecha),
    tipo: movimiento.tipo,
    categoria: movimiento.categoria,
    estado: movimiento.estado,
    recurrente: Boolean(movimiento.recurrenciaId),
    frecuencia: movimiento.recurrencia?.frecuencia ?? null,
  };
}

function formatearMeta(meta) {
  const objetivo = Number(meta.montoObjetivo);
  const reservado = Number(meta.montoReservado);
  return {
    id: meta.id,
    nombre: meta.nombre,
    montoObjetivo: objetivo,
    fechaObjetivo: fechaATexto(meta.fechaObjetivo),
    montoReservado: reservado,
    progreso: objetivo > 0 ? Math.min(reservado / objetivo, 1) : 0,
  };
}

function formatearMovimientoMeta(movimiento) {
  return {
    id: movimiento.id,
    tipo: movimiento.tipo,
    monto: Number(movimiento.monto),
    metaRelacionada: movimiento.metaRelacionada?.nombre ?? null,
    creadoEn: movimiento.creadoEn,
  };
}

async function calcularResumenMetas(usuarioId, cliente = prisma) {
  const ingresos = await cliente.movimiento.aggregate({
    _sum: { monto: true },
    where: { usuarioId, tipo: 'ingreso' },
  });
  const gastos = await cliente.movimiento.aggregate({
    _sum: { monto: true },
    where: { usuarioId, tipo: 'gasto' },
  });
  const reservado = await cliente.metaAhorro.aggregate({
    _sum: { montoReservado: true },
    where: { usuarioId },
  });

  return calcularSaldos({
    ingresos: ingresos._sum.monto === null ? 0 : Number(ingresos._sum.monto),
    gastos: gastos._sum.monto === null ? 0 : Number(gastos._sum.monto),
    reservado:
      reservado._sum.montoReservado === null
        ? 0
        : Number(reservado._sum.montoReservado),
  });
}

// ---------- Protección: exige una sesión válida ----------
async function exigirSesion(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No hay sesión' });

  const sesion = await prisma.sesion.findFirst({
    where: { token, expiraEn: { gt: new Date() } },
    include: { usuario: { select: { id: true, nombre: true, correo: true } } },
  });
  if (!sesion) {
    return res.status(401).json({ error: 'Sesión inválida o expirada' });
  }

  req.usuario = sesion.usuario;
  req.token = token;
  next();
}

// ---------- Ruta pública ----------
app.get('/ping', (req, res) => res.json({ mensaje: 'Servidor funcionando' }));

// ---------- Analítica ----------
app.get('/analitica', async (req, res) => {
  const [iniciados, completados] = await Promise.all([
    prisma.evento.count({ where: { tipo: 'movimiento_iniciado' } }),
    prisma.evento.count({ where: { tipo: 'movimiento_guardado' } }),
  ]);
  const fecha = fechaBolivia();
  console.log("###############");
  console.log(`Fecha ${fecha}`);
  console.log(`Iniciados ${iniciados} - Completados ${completados}`);
  console.log("###############");
  res.json({ fecha, iniciados, completados });
});

app.post('/analitica/eventos', exigirSesion, async (req, res) => {
  const evento = String(req.body.evento || '');
  const validacion = validarEvento(evento, req.body.propiedades);
  if (!validacion.ok) {
    return res.status(400).json({ error: validacion.error });
  }

  await prisma.evento.create({
    data: {
      usuarioId: req.usuario.id,
      tipo: evento,
      propiedades: validacion.propiedades,
    },
  });

  res.status(201).json({ ok: true });
});

// ---------- Registro ----------
app.post('/registro', async (req, res) => {
  const { nombre, correo, contrasena } = req.body;
  if (!nombre || !correo || !contrasena) {
    return res.status(400).json({ error: 'Completa todos los campos' });
  }
  const formato = validarCorreo(correo);
  if (!formato.ok) {
    return res.status(400).json({ error: formato.error });
  }
  if (contrasena.length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener mínimo 6 caracteres' });
  }

  try {
    const hash = await bcrypt.hash(contrasena, 10);
    await prisma.usuario.create({
      data: {
        nombre,
        correo: correo.trim().toLowerCase(),
        contrasenaHash: hash,
      },
    });
    res.status(201).json({ mensaje: 'Cuenta creada' });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }
    throw e;
  }
});

// ---------- Inicio de sesión ----------
app.post('/login', async (req, res) => {
  const { correo, contrasena } = req.body;

  const usuario = await prisma.usuario.findUnique({
    where: { correo: (correo || '').toLowerCase() },
  });

  if (!usuario || !(await bcrypt.compare(contrasena || '', usuario.contrasenaHash))) {
    return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
  }

  const token = crypto.randomBytes(32).toString('hex');
  await prisma.sesion.create({
    data: {
      token,
      usuarioId: usuario.id,
      expiraEn: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    },
  });

  res.json({ token, nombre: usuario.nombre });
});

// ---------- Ruta privada: datos de quien tiene sesión ----------
app.get('/perfil', exigirSesion, (req, res) => {
  res.json({ nombre: req.usuario.nombre, correo: req.usuario.correo });
});

// ---------- Cierre de sesión ----------
app.post('/logout', exigirSesion, async (req, res) => {
  await prisma.sesion.deleteMany({ where: { token: req.token } });
  res.json({ mensaje: 'Sesión cerrada' });
});

// ---------- Eliminar cuenta y todos sus datos ----------
app.delete('/cuenta', exigirSesion, async (req, res) => {
  const contrasena = String(req.body?.contrasena || '');
  if (!contrasena) {
    return res.status(400).json({ error: 'Escribe tu contraseña' });
  }

  const usuario = await prisma.usuario.findUnique({
    where: { id: req.usuario.id },
  });
  if (!usuario || !(await bcrypt.compare(contrasena, usuario.contrasenaHash))) {
    return res.status(403).json({ error: 'Contraseña incorrecta' });
  }

  await prisma.usuario.delete({ where: { id: req.usuario.id } });
  res.json({ mensaje: 'Cuenta eliminada' });
});

// ---------- Exportar datos del usuario (JSON) ----------
app.get('/cuenta/exportar', exigirSesion, async (req, res) => {
  const usuarioId = req.usuario.id;

  const [usuario, movimientos, metas, presupuestos, limites] = await Promise.all([
    prisma.usuario.findUnique({
      where: { id: usuarioId },
      select: { nombre: true, correo: true, creadoEn: true },
    }),
    prisma.movimiento.findMany({
      where: { usuarioId },
      orderBy: { fecha: 'desc' },
      select: {
        id: true,
        concepto: true,
        monto: true,
        fecha: true,
        tipo: true,
        categoria: true,
        estado: true,
      },
    }),
    prisma.metaAhorro.findMany({
      where: { usuarioId },
      orderBy: { creadoEn: 'asc' },
      include: {
        movimientos: {
          orderBy: { creadoEn: 'desc' },
          select: { id: true, tipo: true, monto: true, creadoEn: true },
        },
      },
    }),
    prisma.presupuestoCategoria.findMany({
      where: { usuarioId },
      orderBy: { mes: 'desc' },
      select: { id: true, mes: true, categoria: true, monto: true },
    }),
    prisma.limiteMensual.findMany({
      where: { usuarioId },
      orderBy: { mes: 'desc' },
      select: { id: true, mes: true, monto: true },
    }),
  ]);

  const datosExportados = {
    exportadoEn: new Date().toISOString(),
    usuario: {
      nombre: usuario?.nombre || '',
      correo: usuario?.correo || '',
      miembroDesde: usuario?.creadoEn?.toISOString().slice(0, 10) || '',
    },
    movimientos: movimientos.map((m) => ({
      ...m,
      monto: Number(m.monto),
      fecha: fechaATexto(m.fecha),
    })),
    metas: metas.map((meta) => ({
      id: meta.id,
      nombre: meta.nombre,
      montoObjetivo: Number(meta.montoObjetivo),
      montoReservado: Number(meta.montoReservado),
      fechaObjetivo: fechaATexto(meta.fechaObjetivo),
      movimientos: meta.movimientos.map((mv) => ({
        ...mv,
        monto: Number(mv.monto),
        fecha: mv.creadoEn.toISOString(),
      })),
    })),
    presupuestosCategorias: presupuestos.map((p) => ({
      ...p,
      monto: Number(p.monto),
      mes: fechaATexto(p.mes).slice(0, 7),
    })),
    limitesMensuales: limites.map((l) => ({
      ...l,
      monto: Number(l.monto),
      mes: fechaATexto(l.mes).slice(0, 7),
    })),
  };

  res.json(datosExportados);
});

// ---------- Recuperación: genera un código de 6 dígitos ----------
app.post('/recuperar', async (req, res) => {
  const usuario = await prisma.usuario.findUnique({
    where: { correo: (req.body.correo || '').toLowerCase() },
    select: { id: true },
  });
  if (!usuario) {
    return res.status(404).json({ error: 'Ese correo no está registrado' });
  }

  const codigo = String(Math.floor(100000 + Math.random() * 900000));
  await prisma.recuperacion.create({
    data: {
      usuarioId: usuario.id,
      codigo,
      expiraEn: new Date(Date.now() + 15 * 60 * 1000),
    },
  });

  // No se envía correo real: el código se devuelve para mostrarlo en la app
  res.json({ codigo });
});

// ---------- Cambio de contraseña con el código ----------
app.post('/cambiar-contrasena', async (req, res) => {
  const { correo, codigo, nuevaContrasena } = req.body;
  if (!nuevaContrasena || nuevaContrasena.length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener mínimo 6 caracteres' });
  }

  const recuperacion = await prisma.recuperacion.findFirst({
    where: {
      codigo,
      usado: false,
      expiraEn: { gt: new Date() },
      usuario: { correo: (correo || '').toLowerCase() },
    },
    orderBy: { id: 'desc' },
  });
  if (!recuperacion) {
    return res.status(400).json({ error: 'Código incorrecto o vencido' });
  }

  const hash = await bcrypt.hash(nuevaContrasena, 10);

  await prisma.$transaction([
    prisma.usuario.update({
      where: { id: recuperacion.usuarioId },
      data: { contrasenaHash: hash },
    }),
    prisma.recuperacion.update({
      where: { id: recuperacion.id },
      data: { usado: true },
    }),
    prisma.sesion.deleteMany({ where: { usuarioId: recuperacion.usuarioId } }),
  ]);

  res.json({ mensaje: 'Contraseña actualizada' });
});

// ---------- Movimientos ----------
// Guardar un evento en el historial, dentro de la misma transacción que la acción
async function registrarEvento(tx, { usuarioId, tipo, movimientoId = null, monto = null, descripcion = null }) {
  await tx.evento.create({
    data: { usuarioId, tipo, movimientoId, monto, descripcion },
  });
}

// Listar los movimientos de la persona con sesión, con búsqueda y filtros opcionales
app.get('/movimientos', exigirSesion, async (req, res) => {
  const lectura = leerFiltros(req.query);
  if (!lectura.ok) {
    return res.status(400).json({ error: lectura.error });
  }

  const filas = await prisma.movimiento.findMany({
    where: { usuarioId: req.usuario.id },
    include: { recurrencia: { select: { frecuencia: true } } },
    orderBy: [{ fecha: 'desc' }, { id: 'desc' }],
  });

  // El total sale de la misma lista filtrada que se devuelve: siempre coinciden
  const movimientos = filtrarMovimientos(filas.map(formatearMovimiento), lectura.filtros, hoyTexto());
  res.json({ movimientos, totales: calcularTotales(movimientos) });
});

// Crear un movimiento (siempre nace "pendiente")
app.post('/movimientos', exigirSesion, async (req, res) => {
  const concepto = String(req.body.concepto || '').trim();
  const monto = Number(req.body.monto);
  const fecha = String(req.body.fecha || '');
  const tipo = req.body.tipo ?? 'gasto';
  const categoria = req.body.categoria ?? 'otros';
  const recurrente = req.body.recurrente === true;
  const frecuencia = req.body.frecuencia ?? null;

  if (!concepto || !fecha) {
    return res.status(400).json({ error: 'Completa todos los campos' });
  }
  if (!(monto > 0 && monto < 1e10)) {
    return res.status(400).json({ error: 'El monto debe ser mayor a 0' });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
    return res.status(400).json({ error: 'Fecha inválida' });
  }
  if (!TIPOS.includes(tipo)) {
    return res.status(400).json({ error: 'Tipo inválido' });
  }
  if (!CATEGORIAS.includes(categoria)) {
    return res.status(400).json({ error: 'Categoría inválida' });
  }
  if (recurrente && tipo !== 'gasto') {
    return res.status(400).json({ error: 'Solo los gastos pueden ser recurrentes' });
  }
  if (recurrente && !FRECUENCIAS.includes(frecuencia)) {
    return res.status(400).json({ error: 'Frecuencia inválida' });
  }

  // Solo los gastos cuentan para el límite mensual (#6); un ingreso no se controla
  if (tipo === 'gasto') {
    const control = await controlarLimite(req.usuario.id, fecha, monto);
    if (!control.ok) {
      return res.status(422).json({ error: control.error });
    }
  }

  const montoDecimal = new Prisma.Decimal(monto);

  // El movimiento y su evento viajan en la misma transacción (Tarea 4)
  const guardado = await prisma.$transaction(async (tx) => {
    if (!recurrente) {
      const movimiento = await tx.movimiento.create({
        data: {
          usuarioId: req.usuario.id,
          concepto,
          monto: montoDecimal,
          fecha: textoAFecha(fecha),
          tipo,
          categoria,
        },
        include: { recurrencia: { select: { frecuencia: true } } },
      });

      await registrarEvento(tx, {
        usuarioId: req.usuario.id,
        tipo: tipo === 'ingreso' ? 'ingreso_registrado' : 'gasto_registrado',
        movimientoId: movimiento.id,
        monto: movimiento.monto,
        descripcion: concepto,
      });

      return { movimiento, siguiente: null };
    }

    const fechaBase = textoAFecha(fecha);
    const fechaSiguiente = sumarFrecuencia(fechaBase, frecuencia);
    const fechaDespues = sumarFrecuencia(fechaSiguiente, frecuencia);

    const recurrencia = await tx.recurrencia.create({
      data: {
        usuarioId: req.usuario.id,
        concepto,
        monto: montoDecimal,
        categoria,
        frecuencia,
        proximaFecha: fechaDespues,
      },
    });

    const movimiento = await tx.movimiento.create({
      data: {
        usuarioId: req.usuario.id,
        recurrenciaId: recurrencia.id,
        concepto,
        monto: montoDecimal,
        fecha: fechaBase,
        tipo,
        categoria,
      },
      include: { recurrencia: { select: { frecuencia: true } } },
    });

    const siguiente = await tx.movimiento.create({
      data: {
        usuarioId: req.usuario.id,
        recurrenciaId: recurrencia.id,
        concepto,
        monto: montoDecimal,
        fecha: fechaSiguiente,
        tipo,
        categoria,
      },
      include: { recurrencia: { select: { frecuencia: true } } },
    });

    await registrarEvento(tx, {
      usuarioId: req.usuario.id,
      tipo: 'gasto_registrado',
      movimientoId: movimiento.id,
      monto: movimiento.monto,
      descripcion: concepto,
    });

    return { movimiento, siguiente };
  });

  res.status(201).json({
    movimiento: formatearMovimiento(guardado.movimiento),
    siguiente: guardado.siguiente ? formatearMovimiento(guardado.siguiente) : null,
  });
});

// Marcar como pagado: solo si está pendiente
app.post('/movimientos/:id/pagar', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Movimiento inválido' });
  }

  // El UPDATE y el evento viajan en la misma transacción (Tarea 4)
  const guardado = await prisma.$transaction(async (tx) => {
    const actualizado = await tx.movimiento.updateMany({
      where: { id, usuarioId: req.usuario.id, estado: 'pendiente' },
      data: { estado: 'pagado' },
    });

    // No se actualizó: no existe o ya estaba pagado. No hay nada que guardar.
    if (actualizado.count === 0) return null;

    const movimiento = await tx.movimiento.findUnique({
      where: { id },
      include: { recurrencia: true },
    });
    await registrarEvento(tx, {
      usuarioId: req.usuario.id,
      tipo: 'movimiento_pagado',
      movimientoId: movimiento.id,
      monto: movimiento.monto,
      descripcion: movimiento.concepto,
    });

    if (movimiento.recurrenciaId && movimiento.recurrencia?.activa) {
      const recurrencia = movimiento.recurrencia;
      const fechaSiguiente = recurrencia.proximaFecha;
      const fechaDespues = sumarFrecuencia(fechaSiguiente, recurrencia.frecuencia);

      const existente = await tx.movimiento.findFirst({
        where: { recurrenciaId: recurrencia.id, fecha: fechaSiguiente },
        select: { id: true },
      });

      if (!existente) {
        await tx.movimiento.create({
          data: {
            usuarioId: recurrencia.usuarioId,
            recurrenciaId: recurrencia.id,
            concepto: recurrencia.concepto,
            monto: recurrencia.monto,
            fecha: fechaSiguiente,
            tipo: 'gasto',
            categoria: recurrencia.categoria,
          },
        });
      }

      await tx.recurrencia.update({
        where: { id: recurrencia.id },
        data: { proximaFecha: fechaDespues },
      });
    }

    return movimiento;
  });

  if (!guardado) {
    const existe = await prisma.movimiento.findFirst({
      where: { id, usuarioId: req.usuario.id },
      select: { id: true },
    });
    if (!existe) {
      return res.status(404).json({ error: 'Movimiento no encontrado' });
    }
    return res.status(409).json({ error: 'El movimiento ya está pagado' });
  }

  res.json({ movimiento: formatearMovimiento(guardado) });
});

// Editar: si está pagado, el monto no puede cambiar. El tipo no se modifica.
app.put('/movimientos/:id', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Movimiento inválido' });
  }

  const concepto = String(req.body.concepto || '').trim();
  const monto = Math.round(Number(req.body.monto) * 100) / 100;
  const fecha = String(req.body.fecha || '');
  const categoria = req.body.categoria ?? null; // null = dejar la categoría como está

  if (!concepto || !fecha) {
    return res.status(400).json({ error: 'Completa todos los campos' });
  }
  if (!(monto > 0 && monto < 1e10)) {
    return res.status(400).json({ error: 'El monto debe ser mayor a 0' });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
    return res.status(400).json({ error: 'Fecha inválida' });
  }
  if (categoria !== null && !CATEGORIAS.includes(categoria)) {
    return res.status(400).json({ error: 'Categoría inválida' });
  }

  const actual = await prisma.movimiento.findFirst({
    where: { id, usuarioId: req.usuario.id },
    select: { tipo: true },
  });
  if (!actual) {
    return res.status(404).json({ error: 'Movimiento no encontrado' });
  }

  // Solo los gastos cuentan para el límite. El monto anterior de este movimiento no se cuenta.
  if (actual.tipo === 'gasto') {
    const control = await controlarLimite(req.usuario.id, fecha, monto, id);
    if (!control.ok) {
      return res.status(422).json({ error: control.error });
    }
  }

  const montoDecimal = new Prisma.Decimal(monto);

  // La restricción vive en el WHERE: si está pagado, el monto debe ser el mismo
  const resultado = await prisma.movimiento.updateMany({
    where: {
      id,
      usuarioId: req.usuario.id,
      OR: [{ estado: 'pendiente' }, { monto: montoDecimal }],
    },
    data: {
      concepto,
      monto: montoDecimal,
      fecha: textoAFecha(fecha),
      ...(categoria !== null ? { categoria } : {}),
    },
  });

  // Como el movimiento existe, no actualizar significa: pagado con otro monto
  if (resultado.count === 0) {
    return res.status(409).json({
      error: 'Un movimiento pagado no permite modificar su monto.',
    });
  }

  const guardado = await prisma.movimiento.findUnique({
    where: { id },
    include: { recurrencia: { select: { frecuencia: true } } },
  });
  res.json({ movimiento: formatearMovimiento(guardado) });
});

// Eliminar
app.delete('/movimientos/:id', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Movimiento inválido' });
  }

  const resultado = await prisma.movimiento.deleteMany({
    where: { id, usuarioId: req.usuario.id },
  });
  if (resultado.count === 0) {
    return res.status(404).json({ error: 'Movimiento no encontrado' });
  }
  res.json({ mensaje: 'Movimiento eliminado' });
});

// ---------- Límite mensual (#9) ----------
// 'AAAA-MM' → 'AAAA-MM-01'; sin mes, el mes actual; null si el formato no sirve
function primerDiaDelMes(mes) {
  if (mes == null) {
    const hoy = new Date();
    return `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}-01`;
  }
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(mes)) return null;
  return `${mes}-01`;
}

// null si la persona no definió límite para ese mes
async function leerLimite(usuarioId, mes) {
  const limite = await prisma.limiteMensual.findUnique({
    where: { usuarioId_mes: { usuarioId, mes: textoAFecha(mes) } },
  });
  return limite === null ? null : Number(limite.monto);
}

// Solo los movimientos de tipo gasto cuentan. idExcluido: el que se está editando
async function gastadoDelMes(usuarioId, mes, idExcluido = 0) {
  const desde = textoAFecha(mes);
  const hasta = new Date(desde);
  hasta.setUTCMonth(hasta.getUTCMonth() + 1);

  const resultado = await prisma.movimiento.aggregate({
    _sum: { monto: true },
    where: {
      usuarioId,
      id: { not: idExcluido },
      tipo: 'gasto',
      fecha: { gte: desde, lt: hasta },
    },
  });

  return resultado._sum.monto === null ? 0 : Number(resultado._sum.monto);
}

// Antes de guardar un gasto: ¿entra en el límite del mes de su fecha?
async function controlarLimite(usuarioId, fecha, montoNuevo, idExcluido = 0) {
  const mes = fecha.slice(0, 8) + '01';
  const limite = await leerLimite(usuarioId, mes);
  const gastado = await gastadoDelMes(usuarioId, mes, idExcluido);
  return puedeRegistrarGasto({ limite, gastado, montoNuevo });
}

app.get('/limite', exigirSesion, async (req, res) => {
  const mes = primerDiaDelMes(req.query.mes);
  if (!mes) {
    return res.status(400).json({ error: 'Mes inválido' });
  }

  const limite = await leerLimite(req.usuario.id, mes);
  const gastado = await gastadoDelMes(req.usuario.id, mes);
  res.json({ mes: mes.slice(0, 7), ...calcularResumen({ limite, gastado }) });
});

app.put('/limite', exigirSesion, async (req, res) => {
  const { monto, mes: mesPedido } = req.body || {};
  const mes = primerDiaDelMes(mesPedido);
  if (!mes) {
    return res.status(400).json({ error: 'Mes inválido' });
  }
  const validacion = validarMontoLimite(monto);
  if (!validacion.ok) {
    return res.status(400).json({ error: validacion.error });
  }

  const gastado = await gastadoDelMes(req.usuario.id, mes);
  const contraGastado = validarLimiteContraGastado(monto, gastado);
  if (!contraGastado.ok) {
    return res.status(400).json({ error: contraGastado.error });
  }

  const mesFecha = textoAFecha(mes);
  const montoDecimal = new Prisma.Decimal(Number(monto));

  // El límite y su evento viajan en la misma transacción (Tarea 4)
  await prisma.$transaction(async (tx) => {
    await tx.limiteMensual.upsert({
      where: { usuarioId_mes: { usuarioId: req.usuario.id, mes: mesFecha } },
      create: {
        usuarioId: req.usuario.id,
        mes: mesFecha,
        monto: montoDecimal,
      },
      update: {
        monto: montoDecimal,
        actualizadoEn: new Date(),
      },
    });

    await registrarEvento(tx, {
      usuarioId: req.usuario.id,
      tipo: 'limite_definido',
      monto: montoDecimal,
      descripcion: `Límite del mes ${mes.slice(0, 7)}`,
    });
  });

  res.json({ mes: mes.slice(0, 7), ...calcularResumen({ limite: Number(monto), gastado }) });
});

app.put('/presupuestos-categoria', exigirSesion, async (req, res) => {
  const { mes: mesPedido, categoria, monto } = req.body || {};

  // valida el mes
  const mes = primerDiaDelMes(mesPedido);
  if (!mes) {
    return res.status(400).json({ error: 'Mes inválido' });
  }

  // valida la categoria
  if (!CATEGORIAS.includes(categoria)) {
    return res.status(400).json({ error: 'Categoría inválida' });
  }

  // valida el monto
  const validacion = validarMontoLimite(monto);
  if (!validacion.ok) {
    return res.status(400).json({ error: validacion.error });
  }

  // se guarda en prisma
  const mesFecha = textoAFecha(mes);
  const montoDecimal = new Prisma.Decimal(Number(monto));

  const guardado = await prisma.presupuestoCategoria.upsert({
    where: {
      usuarioId_mes_categoria: {
        usuarioId: req.usuario.id,
        mes: mesFecha,
        categoria,
      },
    },
    create: {
      usuarioId: req.usuario.id,
      mes: mesFecha,
      categoria,
      monto: montoDecimal,
    },
    update: {
      monto: montoDecimal,
      actualizadoEn: new Date(),
    },
  });

  res.json({
    mes: mes.slice(0, 7),
    categoria: guardado.categoria,
    monto: Number(guardado.monto),
  });
});

const redondear = (n) => Math.round(n * 100) / 100;

app.get('/presupuestos-categoria', exigirSesion, async (req, res) => {

  const mes = primerDiaDelMes(req.query.mes);
  if (!mes) {
    return res.status(400).json({ error: 'Mes inválido' });
  }

  // rango mes
  const desde = textoAFecha(mes);
  const hasta = new Date(desde);
  hasta.setUTCMonth(hasta.getUTCMonth() + 1);

  // los presupuestos y gastos reales
  const [presupuestos, gastosPorCat] = await Promise.all([
    prisma.presupuestoCategoria.findMany({
      where: { usuarioId: req.usuario.id, mes: desde },
    }),
    prisma.movimiento.groupBy({
      by: ['categoria'],
      _sum: { monto: true },
      where: {
        usuarioId: req.usuario.id,
        tipo: 'gasto',
        fecha: { gte: desde, lt: hasta },
      },
    }),
  ]);

  // indices acomodados por categoria
  const limitePorCat = new Map(
    presupuestos.map((p) => [p.categoria, Number(p.monto)])
  );
  const gastadoPorCat = new Map(
    gastosPorCat.map((g) => [g.categoria, Number(g._sum.monto ?? 0)])
  );

  // una fila por categoria, tenga o no presupuesto
  const categorias = CATEGORIAS.map((categoria) => {
    const limite = limitePorCat.has(categoria) ? limitePorCat.get(categoria) : null;
    const gastado = redondear(gastadoPorCat.get(categoria) ?? 0);

    return {
      categoria,
      limite,
      gastado,
      restante: limite !== null ? redondear(limite - gastado) : null,
      proporcion: limite !== null ? redondear(gastado / limite) : null,
    };
  });

  res.json({ mes: mes.slice(0, 7), categorias });
});


// ---------- Metas de ahorro ----------
app.get('/metas', exigirSesion, async (req, res) => {
  const metas = await prisma.metaAhorro.findMany({
    where: { usuarioId: req.usuario.id },
    orderBy: { creadoEn: 'asc' },
  });
  const resumen = await calcularResumenMetas(req.usuario.id);
  res.json({ metas: metas.map(formatearMeta), resumen });
});

app.post('/metas', exigirSesion, async (req, res) => {
  const nombre = validarNombreMeta(req.body.nombre);
  if (!nombre.ok) return res.status(400).json({ error: nombre.error });

  const monto = validarMontoMeta(req.body.montoObjetivo, 'monto objetivo');
  if (!monto.ok) return res.status(400).json({ error: monto.error });

  const fecha = validarFechaMeta(req.body.fechaObjetivo);
  if (!fecha.ok) return res.status(400).json({ error: fecha.error });

  try {
    const meta = await prisma.metaAhorro.create({
      data: {
        usuarioId: req.usuario.id,
        nombre: nombre.nombre,
        montoObjetivo: new Prisma.Decimal(monto.monto),
        fechaObjetivo: fecha.fecha,
      },
    });
    const resumen = await calcularResumenMetas(req.usuario.id);
    res.status(201).json({ meta: formatearMeta(meta), resumen });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(409).json({ error: 'Ya tienes una meta con ese nombre' });
    }
    throw error;
  }
});

app.post('/metas/:id/asignar', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Meta inválida' });
  }

  const monto = validarMontoMeta(req.body.monto);
  if (!monto.ok) return res.status(400).json({ error: monto.error });

  const resultado = await prisma.$transaction(async (tx) => {
    const meta = await tx.metaAhorro.findFirst({
      where: { id, usuarioId: req.usuario.id },
    });
    if (!meta) return { status: 404, error: 'Meta no encontrada' };

    const resumen = await calcularResumenMetas(req.usuario.id, tx);
    const control = validarAsignacion({
      disponible: resumen.disponible,
      monto: monto.monto,
    });
    if (!control.ok) return { status: 422, error: control.error };

    const actualizada = await tx.metaAhorro.update({
      where: { id },
      data: {
        montoReservado: { increment: new Prisma.Decimal(monto.monto) },
        actualizadoEn: new Date(),
      },
    });
    await tx.movimientoMeta.create({
      data: {
        usuarioId: req.usuario.id,
        metaId: id,
        tipo: 'asignacion',
        monto: new Prisma.Decimal(monto.monto),
      },
    });
    const nuevoResumen = await calcularResumenMetas(req.usuario.id, tx);
    return { meta: actualizada, resumen: nuevoResumen };
  });

  if (resultado.error) {
    return res.status(resultado.status).json({ error: resultado.error });
  }
  res.json({ meta: formatearMeta(resultado.meta), resumen: resultado.resumen });
});

app.post('/metas/:id/retirar', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Meta inválida' });
  }

  const monto = validarMontoMeta(req.body.monto);
  if (!monto.ok) return res.status(400).json({ error: monto.error });

  const resultado = await prisma.$transaction(async (tx) => {
    const meta = await tx.metaAhorro.findFirst({
      where: { id, usuarioId: req.usuario.id },
    });
    if (!meta) return { status: 404, error: 'Meta no encontrada' };

    const control = validarRetiro({
      reservado: Number(meta.montoReservado),
      monto: monto.monto,
    });
    if (!control.ok) return { status: 422, error: control.error };

    const actualizada = await tx.metaAhorro.update({
      where: { id },
      data: {
        montoReservado: { decrement: new Prisma.Decimal(monto.monto) },
        actualizadoEn: new Date(),
      },
    });
    await tx.movimientoMeta.create({
      data: {
        usuarioId: req.usuario.id,
        metaId: id,
        tipo: 'retiro',
        monto: new Prisma.Decimal(monto.monto),
      },
    });
    const nuevoResumen = await calcularResumenMetas(req.usuario.id, tx);
    return { meta: actualizada, resumen: nuevoResumen };
  });

  if (resultado.error) {
    return res.status(resultado.status).json({ error: resultado.error });
  }
  res.json({ meta: formatearMeta(resultado.meta), resumen: resultado.resumen });
});

app.post('/metas/:id/transferir', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  const metaDestinoId = Number(req.body.metaDestinoId);
  if (!Number.isInteger(id) || !Number.isInteger(metaDestinoId)) {
    return res.status(400).json({ error: 'Meta inválida' });
  }
  if (id === metaDestinoId) {
    return res.status(400).json({ error: 'Elige una meta de destino distinta' });
  }

  const monto = validarMontoMeta(req.body.monto);
  if (!monto.ok) return res.status(400).json({ error: monto.error });

  const resultado = await prisma.$transaction(async (tx) => {
    const origen = await tx.metaAhorro.findFirst({
      where: { id, usuarioId: req.usuario.id },
    });
    const destino = await tx.metaAhorro.findFirst({
      where: { id: metaDestinoId, usuarioId: req.usuario.id },
    });
    if (!origen || !destino) {
      return { status: 404, error: 'Meta no encontrada' };
    }

    const control = validarTransferencia({
      reservado: Number(origen.montoReservado),
      monto: monto.monto,
    });
    if (!control.ok) return { status: 422, error: control.error };

    const origenActualizado = await tx.metaAhorro.update({
      where: { id: origen.id },
      data: {
        montoReservado: { decrement: new Prisma.Decimal(monto.monto) },
        actualizadoEn: new Date(),
      },
    });
    const destinoActualizado = await tx.metaAhorro.update({
      where: { id: destino.id },
      data: {
        montoReservado: { increment: new Prisma.Decimal(monto.monto) },
        actualizadoEn: new Date(),
      },
    });
    await tx.movimientoMeta.createMany({
      data: [
        {
          usuarioId: req.usuario.id,
          metaId: origen.id,
          metaRelacionadaId: destino.id,
          tipo: 'transferencia_salida',
          monto: new Prisma.Decimal(monto.monto),
        },
        {
          usuarioId: req.usuario.id,
          metaId: destino.id,
          metaRelacionadaId: origen.id,
          tipo: 'transferencia_entrada',
          monto: new Prisma.Decimal(monto.monto),
        },
      ],
    });
    const nuevoResumen = await calcularResumenMetas(req.usuario.id, tx);
    return {
      meta: origenActualizado,
      metaDestino: destinoActualizado,
      resumen: nuevoResumen,
    };
  });

  if (resultado.error) {
    return res.status(resultado.status).json({ error: resultado.error });
  }
  res.json({
    meta: formatearMeta(resultado.meta),
    metaDestino: formatearMeta(resultado.metaDestino),
    resumen: resultado.resumen,
  });
});

app.get('/metas/:id/movimientos', exigirSesion, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Meta inválida' });
  }

  const meta = await prisma.metaAhorro.findFirst({
    where: { id, usuarioId: req.usuario.id },
    select: { id: true },
  });
  if (!meta) {
    return res.status(404).json({ error: 'Meta no encontrada' });
  }

  const filas = await prisma.movimientoMeta.findMany({
    where: { usuarioId: req.usuario.id, metaId: id },
    include: { metaRelacionada: { select: { nombre: true } } },
    orderBy: { creadoEn: 'desc' },
  });
  res.json({ movimientos: filas.map(formatearMovimientoMeta) });
});

// ---------- Historial de actividad (Tarea 4) ----------
app.get('/historial', exigirSesion, async (req, res) => {
  const filtro = String(req.query.tipo || 'todos');
  if (!FILTROS_HISTORIAL.includes(filtro)) {
    return res.status(400).json({ error: 'Filtro inválido' });
  }

  const filas = await prisma.evento.findMany({
    where: {
      usuarioId: req.usuario.id,
      tipo: { notIn: Object.keys(EVENTOS) },
    },
    orderBy: { creadoEn: 'desc' },
    take: 50,
  });

  const eventos = filas.map((evento) => ({
    id: evento.id,
    tipo: evento.tipo,
    movimiento_id: evento.movimientoId,
    monto: evento.monto === null ? null : Number(evento.monto),
    descripcion: evento.descripcion,
    creado_en: evento.creadoEn,
  }));

  const grupos = armarHistorial(eventos, filtro, new Date());
  res.json({ grupos });
});

// ---------- Manejo de errores ----------
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Error del servidor' });
});

if (require.main === module) {
  app.listen(puerto, () => console.log(`Servidor en http://localhost:${puerto}`));
}

module.exports = app;


