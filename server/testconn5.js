const { Pool } = require('pg');
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'postgres',
  password: '10262001',
  port: 5432,
});
pool.query('SELECT 1').then(r => {
  console.log('ok');
  pool.end();
  process.exit(0);
}).catch(e => {
  console.error('err', e.message);
  pool.end();
  process.exit(1);
});
