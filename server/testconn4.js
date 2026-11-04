const { Pool } = require('pg');
const pool = new Pool({
  user: 'Admin',
  host: 'localhost',
  database: 'postgres',
  port: 5432,
});
pool.query('SELECT 1').then(r => {
  console.log('ok');
  pool.end();
  process.exit(0);
}).catch(e => {
  console.error('err');
  pool.end();
  process.exit(1);
});
