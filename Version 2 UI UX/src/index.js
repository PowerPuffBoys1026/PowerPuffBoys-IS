const app = require('./app');
const config = require('./config');

app.listen(config.port, () => {
  console.log(`ClassMate API listening on http://localhost:${config.port}`);
  console.log(`Health check:  http://localhost:${config.port}/api/health`);
});
