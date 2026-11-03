const app = require('./app');
const config = require('./config');
const { init } = require('./db');

async function start() {
  // Fail fast if Postgres is unreachable or the schema cannot be created.
  await init();

  app.listen(config.port, () => {
    console.log(`ClassMate API listening on http://localhost:${config.port}`);
    console.log(`Health check:  http://localhost:${config.port}/api/health`);
  });
}

start().catch((err) => {
  console.error('Failed to start ClassMate API:', err);
  process.exit(1);
});
