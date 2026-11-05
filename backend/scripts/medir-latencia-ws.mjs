import { io } from 'socket.io-client';

const url = process.env.WS_URL;
const serenoToken = process.env.SERENO_TOKEN;
const operadorToken = process.env.OPERADOR_TOKEN;
const n = Number(process.env.N || 100);
const cold = process.argv.includes('--cold');

if (!url || !serenoToken || !operadorToken) {
  console.error('Faltan WS_URL, SERENO_TOKEN, OPERADOR_TOKEN');
  process.exit(1);
}

const sereno = io(url, { auth: { token: serenoToken }, transports: ['websocket'] });
const operador = io(url, { auth: { token: operadorToken }, transports: ['websocket'] });

const received = [];
let sent = 0;
operador.on('posicion_unidad', (d) => received.push({ ...d, recvAt: Date.now() }));

sereno.on('connect', async () => {
  if (cold) await new Promise((r) => setTimeout(r, 0));
  const start = Date.now();
  for (let i = 0; i < n; i++) {
    sereno.emit('posicion_unidad', { unidadId: process.env.UNIDAD_ID, latitud: -3.5 + i * 0.0001, longitud: -80.3, velocidad: 0, rumbo: 0 });
    sent++;
    await new Promise((r) => setTimeout(r, 50));
  }
  await new Promise((r) => setTimeout(r, 2000));
  const latencies = received.map((r) => r.recvAt - (r.serverTime ? new Date(r.serverTime).getTime() : start));
  latencies.sort((a, b) => a - b);
  const median = latencies[Math.floor(latencies.length / 2)] || 0;
  const p95 = latencies[Math.floor(latencies.length * 0.95)] || 0;
  const max = latencies[latencies.length - 1] || 0;
  const loss = sent - received.length;
  console.log(JSON.stringify({ sent, received: received.length, loss, median, p95, max, cold }, null, 2));
  sereno.disconnect();
  operador.disconnect();
  process.exit(0);
});
operador.on('connect', () => {});
