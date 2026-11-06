const app = require('./app');
const config = require('./config');
const db = require('./db');

let shuttingDown = false;

function installShutdownHandlers(server) {
  const shutdown = (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`\n${signal} received. Shutting down...`);

    const forceExit = setTimeout(() => {
      console.error('Shutdown timed out; forcing exit.');
      process.exit(1);
    }, 10000);
    forceExit.unref();

    server.close(async (error) => {
      try {
        await db.end();
      } catch (poolError) {
        console.error('Failed to close PostgreSQL pool:', poolError.message);
      }
      clearTimeout(forceExit);

      if (error) {
        console.error('Failed to close HTTP server:', error.message);
        process.exit(1);
      }

      console.log('Shutdown complete.');
      process.exit(0);
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

async function start() {
  try {
    const applied = await db.initDb();
    if (applied) console.log(`Applied ${applied} database migration(s).`);

    const server = app.listen(config.port, () => {
      console.log(`ClassMate API listening on http://localhost:${config.port}`);
      console.log(`Health check:  http://localhost:${config.port}/api/health`);
    });

    installShutdownHandlers(server);
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

start();
