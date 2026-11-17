const ALLOWED_HOSTS = new Set(['localhost', '127.0.0.1']);

function validarHost(url) {
  let host;
  try {
    host = new URL(url).hostname;
  } catch {
    throw new Error('test:e2e abortado: DATABASE_URL no es una URL valida.');
  }

  const optIn = process.env.E2E_ALLOW_DB_HOST;
  const permitido = ALLOWED_HOSTS.has(host) || (optIn && optIn === host);

  if (!permitido) {
    throw new Error(
      `test:e2e abortado: host de base de datos no permitido (${host}). ` +
      `Usa localhost/127.0.0.1 o define E2E_ALLOW_DB_HOST=${host}.`
    );
  }

  return host;
}

async function setup() {
  const url = process.env.DATABASE_URL || '';
  validarHost(url);
}

module.exports = setup;
module.exports.validarHost = validarHost;
