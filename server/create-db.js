const { Client } = require('pg');

async function run() {
  const client = new Client({
    user: 'postgres',
    host: 'localhost',
    database: 'postgres',
    password: 'postgres',
    port: 5432,
  });
  try {
    await client.connect();
    await client.query('CREATE DATABASE classmate;');
    console.log('created');
  } catch (e) {
    console.error('err', e.message);
  } finally {
    await client.end();
  }
}

run();
