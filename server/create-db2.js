const { Client } = require('pg');

async function run() {
  const passwords = ['', 'postgres', 'admin', 'root', '123456'];
  for (const pw of passwords) {
    const client = new Client({
      user: 'postgres',
      host: 'localhost',
      database: 'postgres',
      password: pw,
      port: 5432,
    });
    try {
      await client.connect();
      try {
        await client.query('CREATE DATABASE classmate;');
        console.log('created with pass:', pw);
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
      // try next
    }
  }
  console.log('failed');
}

run();
