require('dotenv').config();

const db = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || '5432',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  name: process.env.DB_NAME || 'postgres',
};

const credenciales = db.password
  ? `${db.user}:${db.password}`
  : db.user;

const databaseUrl =
  `postgresql://${credenciales}@${db.host}:${db.port}/${db.name}?schema=public`;

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  puerto: Number(process.env.SERVER_PORT || process.env.PUERTO) || 3000,
  db,
  databaseUrl,
};

module.exports = env;
