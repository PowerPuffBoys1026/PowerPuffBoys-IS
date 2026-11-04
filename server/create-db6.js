const { Client } = require('pg');

async function run() {
  try {
    const client = new Client({
      user: 'postgres',
      host: 'localhost',
      database: 'postgres',
      port: 5432,
      password: '',
    });
    await client.connect();
    try {
      await client.query('CREATE DATABASE classmate;');
      console.log('created');
    } catch (e) {
      if (e.message.includes('already exists')) {
        console.log('exists');
      } else {
        console.log('create err', e.message);
      }
    }
    await client.end();
    return;
  } catch (e) {
    console.error('err', e.message);
  }
}

run();
