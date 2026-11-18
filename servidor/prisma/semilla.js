const bcrypt = require('bcryptjs');
const prisma = require('../conexion');

const inicioMes = () => {
  const hoy = new Date();
  return new Date(Date.UTC(hoy.getUTCFullYear(), hoy.getUTCMonth(), 1));
};

const fechaMes = (dia) => {
  const hoy = new Date();
  return new Date(Date.UTC(hoy.getUTCFullYear(), hoy.getUTCMonth(), dia));
};

const fechaFutura = (meses) => {
  const hoy = new Date();
  return new Date(Date.UTC(hoy.getUTCFullYear(), hoy.getUTCMonth() + meses, 1));
};

const usuarios = [
  {
    correo: 'prueba@correo.com',
    nombre: 'Usuario Prueba',
    movimientos: [
      {
        concepto: 'Ingreso de prueba',
        monto: '1000.00',
        fecha: fechaMes(1),
        tipo: 'ingreso',
        categoria: 'otros',
        estado: 'pagado',
      },
      {
        concepto: 'Gasto de prueba',
        monto: '400.00',
        fecha: fechaMes(2),
        tipo: 'gasto',
        categoria: 'comida',
        estado: 'pagado',
      },
    ],
    metas: [
      {
        nombre: 'Fondo de emergencia',
        montoObjetivo: '500.00',
        fechaObjetivo: fechaFutura(3),
      },
      { nombre: 'Viaje', montoObjetivo: '300.00', fechaObjetivo: fechaFutura(6) },
    ],
  },
  {
    correo: 'prueba1@correo.com',
    nombre: 'Ana Torres',
    movimientos: [
      {
        concepto: 'Salario de ejemplo',
        monto: '1800.00',
        fecha: fechaMes(1),
        tipo: 'ingreso',
        categoria: 'otros',
        estado: 'pagado',
      },
      {
        concepto: 'Alquiler',
        monto: '450.00',
        fecha: fechaMes(2),
        tipo: 'gasto',
        categoria: 'otros',
        estado: 'pagado',
      },
      {
        concepto: 'Mercado semanal',
        monto: '120.50',
        fecha: fechaMes(3),
        tipo: 'gasto',
        categoria: 'comida',
        estado: 'pagado',
      },
      {
        concepto: 'Pasaje universitario',
        monto: '40.00',
        fecha: fechaMes(4),
        tipo: 'gasto',
        categoria: 'transporte',
        estado: 'pendiente',
      },
    ],
    metas: [
      {
        nombre: 'Laptop',
        montoObjetivo: '800.00',
        fechaObjetivo: fechaFutura(4),
        montoReservado: '250.00',
      },
      {
        nombre: 'Fondo de emergencia',
        montoObjetivo: '500.00',
        fechaObjetivo: fechaFutura(6),
        montoReservado: '100.00',
      },
    ],
    limite: '1200.00',
    presupuestos: [
      { categoria: 'comida', monto: '450.00' },
      { categoria: 'transporte', monto: '250.00' },
      { categoria: 'estudio', monto: '200.00' },
    ],
    recurrencias: [
      {
        concepto: 'Alquiler',
        monto: '450.00',
        categoria: 'otros',
        frecuencia: 'mensual',
        proximaFecha: fechaFutura(1),
      },
    ],
  },
  {
    correo: 'prueba2@correo.com',
    nombre: 'Luis Rojas',
    movimientos: [
      {
        concepto: 'Trabajo freelance',
        monto: '1200.00',
        fecha: fechaMes(1),
        tipo: 'ingreso',
        categoria: 'otros',
        estado: 'pagado',
      },
      {
        concepto: 'Almuerzo',
        monto: '90.00',
        fecha: fechaMes(2),
        tipo: 'gasto',
        categoria: 'comida',
        estado: 'pagado',
      },
      {
        concepto: 'Transporte mensual',
        monto: '30.00',
        fecha: fechaMes(3),
        tipo: 'gasto',
        categoria: 'transporte',
        estado: 'pagado',
      },
      {
        concepto: 'Curso de inglés',
        monto: '150.00',
        fecha: fechaMes(5),
        tipo: 'gasto',
        categoria: 'estudio',
        estado: 'pendiente',
      },
    ],
    metas: [
      {
        nombre: 'Viaje a la playa',
        montoObjetivo: '600.00',
        fechaObjetivo: fechaFutura(5),
        montoReservado: '150.00',
      },
      {
        nombre: 'Curso de inglés',
        montoObjetivo: '400.00',
        fechaObjetivo: fechaFutura(8),
        montoReservado: '50.00',
      },
    ],
    limite: '900.00',
    presupuestos: [
      { categoria: 'comida', monto: '300.00' },
      { categoria: 'transporte', monto: '150.00' },
      { categoria: 'estudio', monto: '250.00' },
    ],
    recurrencias: [
      {
        concepto: 'Internet',
        monto: '80.00',
        categoria: 'otros',
        frecuencia: 'mensual',
        proximaFecha: fechaFutura(1),
      },
    ],
  },
];

async function sembrarUsuario(datos, hash) {
  const usuario = await prisma.usuario.upsert({
    where: { correo: datos.correo },
    update: { contrasenaHash: hash },
    create: {
      nombre: datos.nombre,
      correo: datos.correo,
      contrasenaHash: hash,
    },
  });

  const movimientos = await prisma.movimiento.count({
    where: { usuarioId: usuario.id },
  });
  if (movimientos === 0) {
    await prisma.movimiento.createMany({
      data: datos.movimientos.map((movimiento) => ({
        ...movimiento,
        usuarioId: usuario.id,
      })),
    });
  }

  const metas = [];
  for (const meta of datos.metas) {
    const creada = await prisma.metaAhorro.upsert({
      where: {
        usuarioId_nombre: { usuarioId: usuario.id, nombre: meta.nombre },
      },
      update: {},
      create: {
        ...meta,
        montoReservado: meta.montoReservado ?? '0.00',
        usuarioId: usuario.id,
      },
    });
    metas.push({ ...creada, reservadoSemilla: meta.montoReservado ?? '0.00' });
  }

  if (datos.limite) {
    await prisma.limiteMensual.upsert({
      where: {
        usuarioId_mes: { usuarioId: usuario.id, mes: inicioMes() },
      },
      update: {},
      create: {
        usuarioId: usuario.id,
        mes: inicioMes(),
        monto: datos.limite,
      },
    });
  }

  for (const presupuesto of datos.presupuestos ?? []) {
    await prisma.presupuestoCategoria.upsert({
      where: {
        usuarioId_mes_categoria: {
          usuarioId: usuario.id,
          mes: inicioMes(),
          categoria: presupuesto.categoria,
        },
      },
      update: {},
      create: {
        usuarioId: usuario.id,
        mes: inicioMes(),
        categoria: presupuesto.categoria,
        monto: presupuesto.monto,
      },
    });
  }

  const recurrencias = await prisma.recurrencia.count({
    where: { usuarioId: usuario.id },
  });
  if (recurrencias === 0 && datos.recurrencias?.length) {
    await prisma.recurrencia.createMany({
      data: datos.recurrencias.map((recurrencia) => ({
        ...recurrencia,
        usuarioId: usuario.id,
      })),
    });
  }

  const reservas = await prisma.movimientoMeta.count({
    where: { usuarioId: usuario.id },
  });
  if (reservas === 0) {
    for (const meta of metas) {
      if (Number(meta.reservadoSemilla) > 0) {
        await prisma.movimientoMeta.create({
          data: {
            usuarioId: usuario.id,
            metaId: meta.id,
            tipo: 'asignar',
            monto: meta.reservadoSemilla,
          },
        });
      }
    }
  }

  return usuario;
}

async function sembrar() {
  const hash = await bcrypt.hash('123456', 10);

  for (const datos of usuarios) {
    await sembrarUsuario(datos, hash);
  }

  console.log('Semilla cargada:');
  for (const usuario of usuarios) {
    console.log(`- ${usuario.correo} / 123456 (${usuario.nombre})`);
  }
}

sembrar()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
