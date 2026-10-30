const { defineConfig } = require('prisma/config');
const env = require('./env');

// Prisma necesita esta variable 
process.env.DATABASE_URL = env.databaseUrl;
module.exports = defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'node semilla.js',
  },
  engine: 'classic',
  datasource: {
    url: env.databaseUrl, 
  },
});
