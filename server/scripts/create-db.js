const path = require('node:path');
const { Client } = require('pg');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const config = require('../src/config');

async function main() {
  const client = new Client({
    host: config.pgHost,
    port: config.pgPort,
    database: config.pgMaintenanceDatabase,
    user: config.pgUser,
    password: config.pgPassword,
  });

  try {
    await client.connect();
    await client.query(`CREATE DATABASE "${config.pgDatabase.replaceAll('"', '""')}"`);
    console.log(`Created PostgreSQL database "${config.pgDatabase}".`);
  } catch (error) {
    if (error.code === '42P04') {
      console.log(`PostgreSQL database "${config.pgDatabase}" already exists.`);
      return;
    }
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error('Failed to create PostgreSQL database:', error.message);
  process.exitCode = 1;
});
