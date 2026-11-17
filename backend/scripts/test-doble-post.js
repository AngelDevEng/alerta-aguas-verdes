// scripts/test-doble-post.js
// Prueba 15: dos POST simultáneos con el mismo X-Device-Id.
// Verifica que solo queda UNA alerta viva (dedupe del backend).
//
// Variables de entorno:
//   BASE_URL        URL de la API en Render (default: https://alerta-aguas-verdes-api.onrender.com)
//   ADMIN_TOKEN     JWT de un usuario ADMIN o SERENO (opcional, el endpoint es público)
//   X_DEVICE_ID     identificador de dispositivo para la prueba (default: test-dispositivo-doble-001)
//
// Uso:
//   ADMIN_TOKEN=<jwt> X_DEVICE_ID=test-dispositivo-doble-001 node scripts/test-doble-post.js

const https = require('https');

const BASE_URL = process.env.BASE_URL || 'https://alerta-aguas-verdes-api.onrender.com';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;
const X_DEVICE_ID = process.env.X_DEVICE_ID || 'test-dispositivo-doble-001';

const URL = new URL(BASE_URL);
const HOST = URL.hostname;
const PORT = URL.port || 443;

function crearAlerta() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      latitud: -3.4825,
      longitud: -80.245,
      telefono: '51900000000',
      direccion: 'Prueba doble POST simultáneo',
      origen: 'APP',
    });

    const options = {
      hostname: HOST,
      port: PORT,
      path: '/api/v1/alertas',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'X-Device-Id': X_DEVICE_ID,
        ...(ADMIN_TOKEN ? { Authorization: `Bearer ${ADMIN_TOKEN}` } : {}),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          console.log(`[HTTP] ${res.statusCode} id=${json.id} sessionToken=${json.sessionToken ? json.sessionToken.slice(0, 12) + '...' : 'null'}`);
          resolve({ status: res.statusCode, id: json.id, sessionToken: json.sessionToken });
        } catch (e) {
          reject(new Error(`Respuesta no es JSON (${res.statusCode}): ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  console.log(`[POST] Enviando 2 peticiones simultáneas con X-Device-Id=${X_DEVICE_ID} ...`);

  const resultados = await Promise.allSettled([crearAlerta(), crearAlerta()]);

  const ids = new Set();
  let exitosos = 0;
  let fallidos = 0;

  for (const r of resultados) {
    if (r.status === 'fulfilled') {
      exitosos++;
      if (r.value.id) ids.add(r.value.id);
      console.log(`  Resultado: status=${r.value.status} id=${r.value.id}`);
    } else {
      fallidos++;
      console.log(`  Resultado: ERROR ${r.reason.message}`);
    }
  }

  console.log('\n--- RESULTADO PRUEBA 15 ---');
  console.log(`Peticiones exitosas: ${exitosos}/2`);
  console.log(`Peticiones fallidas: ${fallidos}/2`);
  console.log(`IDs de alerta distintas: ${ids.size} (${Array.from(ids).join(', ')})`);

  if (exitosos === 2 && ids.size === 1) {
    console.log('PRUEBA 15: EXITOSA (dedupe funcionó: una sola alerta viva)');
  } else {
    console.log('PRUEBA 15: FALLIDA (se crearon más de una alerta para el mismo dispositivo)');
  }
}

main();