// scripts/test-ws-sos-alerta.js
// Prueba 8: conectar un sereno por WebSocket, crear una alerta y mostrar que
// llega nueva_alerta_sos a la sala serenos.
//
// Requisitos: node, socket.io-client.
//
// Variables de entorno:
//   BASE_URL        URL de la API en Render (default: https://alerta-aguas-verdes-api.onrender.com)
//   SERENO_TOKEN    JWT de un usuario con rol SERENO (OBLIGATORIO)
//   X_DEVICE_ID     identificador de dispositivo para la prueba (default: test-dispositivo-ws-001)
//
// Uso:
//   SERENO_TOKEN=<mi-jwt> node scripts/test-ws-sos-alerta.js
//   SERENO_TOKEN=<mi-jwt> X_DEVICE_ID=test-ws-002 node scripts/test-ws-sos-alerta.js

const io = require('socket.io-client');
const https = require('https');

const BASE_URL = process.env.BASE_URL || 'https://alerta-aguas-verdes-api.onrender.com';
const SERENO_TOKEN = process.env.SERENO_TOKEN;
const X_DEVICE_ID = process.env.X_DEVICE_ID || 'test-dispositivo-ws-001';

if (!SERENO_TOKEN) {
  console.error('Falta SERENO_TOKEN. Ejemplo:');
  console.error('  SERENO_TOKEN=<jwt-de-sereno> node scripts/test-ws-sos-alerta.js');
  process.exit(1);
}

const URL = new URL(BASE_URL);
const HOST = URL.hostname;
const PORT = URL.port || 443;
const WS_URL = BASE_URL.replace(/^https/, 'wss') + '/ws';

let alertsReceived = [];
let alertaIdCreada = null;

function crearAlerta() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      latitud: -3.4825,
      longitud: -80.245,
      telefono: '51900000000',
      direccion: 'Prueba WebSocket Fase 1',
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
        Authorization: `Bearer ${SERENO_TOKEN}`,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          console.log(`[HTTP] POST /alertas -> ${res.statusCode}`, JSON.stringify(json));
          alertaIdCreada = json.id;
          resolve(json);
        } catch (e) {
          reject(new Error('Respuesta no es JSON: ' + body));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  console.log(`[WS] Conectando a ${WS_URL} ...`);
  console.log(`[WS] Token SERENO: ${SERENO_TOKEN.slice(0, 20)}...`);
  console.log(`[WS] X-Device-Id: ${X_DEVICE_ID}`);

  const socket = io(WS_URL, {
    transports: ['websocket'],
    auth: { token: SERENO_TOKEN },
    reconnection: false,
    timeout: 10000,
  });

  socket.on('connect', () => {
    console.log('[WS] Conectado. Unido a salas central y serenos.');
    socket.on('nueva_alerta_sos', (d) => {
      alertsReceived.push(d);
      console.log('[WS] nueva_alerta_sos recibida:', JSON.stringify(d));
    });

    setTimeout(async () => {
      try {
        await crearAlerta();
        console.log(`[HTTP] Alerta creada con id=${alertaIdCreada}`);
      } catch (e) {
        console.error('[HTTP] Error creando alerta:', e.message);
      }
    }, 1000);

    setTimeout(() => {
      console.log('\n--- RESULTADO PRUEBA 8 ---');
      console.log(`Eventos nueva_alerta_sos recibidos: ${alertsReceived.length}`);
      const coincide = alertsReceived.some((e) => e.id === alertaIdCreada);
      console.log(`Coincide con alerta creada (${alertaIdCreada}): ${coincide}`);
      if (alertsReceived.length > 0 && coincide) {
        console.log('PRUEBA 8: EXITOSA');
      } else {
        console.log('PRUEBA 8: FALLIDA');
      }
      socket.disconnect();
      process.exit(0);
    }, 3000);
  });

  socket.on('connect_error', (err) => {
    console.error('[WS] Error de conexión:', err.message);
    process.exit(1);
  });

  setTimeout(() => {
    console.error('[WS] Timeout esperando eventos.');
    socket.disconnect();
    process.exit(1);
  }, 10000);
}

main();