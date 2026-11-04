const app = require('./app');
const config = require('./config');
const db = require('./db');

async function start() {
  try {
    if (typeof db.initDb === 'function') {
      await db.initDb();
    }
    app.listen(config.port, () => {
      console.log(`ClassMate API listening on http://localhost:${config.port}`);
      console.log(`Health check:  http://localhost:${config.port}/api/health`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

start();
