const bcrypt = require('bcryptjs');
const prisma = require('./conexion');

async function sembrar() {
  const hash = await bcrypt.hash('123456', 10);

  await prisma.usuario.upsert({
    where: { correo: 'prueba@correo.com' },
    update: { contrasenaHash: hash },
    create: {
      nombre: 'Usuario Prueba',
      correo: 'prueba@correo.com',
      contrasenaHash: hash,
    },
  });

  console.log('Semilla cargada: prueba@correo.com / 123456');
}

sembrar()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
