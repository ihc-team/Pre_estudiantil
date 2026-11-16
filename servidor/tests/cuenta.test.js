const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../servidor');
const prisma = require('../conexion');

const correo = `cuenta-test-${Date.now()}@correo.com`;
const contrasena = '123456';

let servidor;
let base;
let token;
let usuarioId;

async function pedir(metodo, ruta, { token, body } = {}) {
  const respuesta = await fetch(`${base}${ruta}`, {
    method: metodo,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const datos = await respuesta.json();
  return { status: respuesta.status, datos };
}

before(async () => {
  servidor = await new Promise((resolve) => {
    const instancia = app.listen(0, () => resolve(instancia));
  });
  base = `http://127.0.0.1:${servidor.address().port}`;

  const registro = await pedir('POST', '/registro', {
    body: { nombre: 'Cuenta Test', correo, contrasena },
  });
  assert.equal(registro.status, 201);

  const login = await pedir('POST', '/login', {
    body: { correo, contrasena },
  });
  assert.equal(login.status, 200);
  token = login.datos.token;

  const usuario = await prisma.usuario.findUnique({
    where: { correo },
    select: { id: true },
  });
  usuarioId = usuario.id;

  const movimiento = await pedir('POST', '/movimientos', {
    token,
    body: {
      concepto: 'Movimiento de prueba',
      monto: 10,
      fecha: new Date().toISOString().slice(0, 10),
      tipo: 'gasto',
      categoria: 'comida',
    },
  });
  assert.equal(movimiento.status, 201);
});

after(async () => {
  try {
    await prisma.usuario.deleteMany({ where: { correo } });
  } catch {
    // Si la base no estaba disponible, no hay nada que limpiar.
  }

  if (servidor) {
    await new Promise((resolve) => servidor.close(resolve));
  }
  await prisma.$disconnect();
});

test('elimina la cuenta y todos sus datos', async () => {
  const incorrecta = await pedir('DELETE', '/cuenta', {
    token,
    body: { contrasena: 'incorrecta' },
  });
  assert.equal(incorrecta.status, 403);

  const sigue = await prisma.usuario.findUnique({ where: { correo } });
  assert.ok(sigue);

  const eliminada = await pedir('DELETE', '/cuenta', {
    token,
    body: { contrasena },
  });
  assert.equal(eliminada.status, 200);

  const usuario = await prisma.usuario.findUnique({ where: { correo } });
  assert.equal(usuario, null);

  const movimientos = await prisma.movimiento.count({ where: { usuarioId } });
  assert.equal(movimientos, 0);

  const sesiones = await prisma.sesion.count({ where: { usuarioId } });
  assert.equal(sesiones, 0);

  const login = await pedir('POST', '/login', {
    body: { correo, contrasena },
  });
  assert.equal(login.status, 401);

  // Un token anterior ya no debe ser válido tras la eliminación
  const exportarConTokenViejo = await pedir('GET', '/cuenta/exportar', { token });
  assert.equal(exportarConTokenViejo.status, 401);
});

test('exporta los datos completos del usuario en JSON', async () => {
  const correoExportar = `exportar-test-${Date.now()}@correo.com`;
  const reg = await pedir('POST', '/registro', {
    body: { nombre: 'Usuario Exportar', correo: correoExportar, contrasena },
  });
  assert.equal(reg.status, 201);

  const log = await pedir('POST', '/login', {
    body: { correo: correoExportar, contrasena },
  });
  const tokenExportar = log.datos.token;

  await pedir('POST', '/movimientos', {
    token: tokenExportar,
    body: {
      concepto: 'Gasto para exportar',
      monto: 25.5,
      fecha: new Date().toISOString().slice(0, 10),
      tipo: 'gasto',
      categoria: 'comida',
    },
  });

  const exportado = await pedir('GET', '/cuenta/exportar', { token: tokenExportar });
  assert.equal(exportado.status, 200);
  assert.ok(exportado.datos.exportadoEn);
  assert.equal(exportado.datos.usuario.correo, correoExportar);
  assert.equal(exportado.datos.movimientos.length, 1);
  assert.equal(exportado.datos.movimientos[0].concepto, 'Gasto para exportar');
  assert.equal(exportado.datos.movimientos[0].monto, 25.5);
  assert.ok(Array.isArray(exportado.datos.metas));
  assert.ok(Array.isArray(exportado.datos.presupuestosCategorias));

  // Limpiar
  await prisma.usuario.deleteMany({ where: { correo: correoExportar } });
});
