const { Pool } = require('pg');
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'postgres',
  password: '',
  port: 5432,
});
pool.query('SELECT 1', (err, res) => {
  if (err) {
    console.error('err');
    process.exit(1);
  }
  console.log('ok');
  pool.end();
  process.exit(0);
});
