import { Client } from 'pg';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

const require = createRequire(import.meta.url);
const bcrypt = require('bcryptjs');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RAIZ_BACKEND = path.resolve(__dirname, '..');

dotenv.config({ path: path.resolve(RAIZ_BACKEND, '.env') });

const CLIENTES = [
  { dni: '00000001', rol: 'OPERADOR', email: 'operador@muniaguasverdes.gob.pe' },
  { dni: '00000002', rol: 'ADMIN', email: 'admin@muniaguasverdes.gob.pe' },
  { dni: '00000003', rol: 'SERENO', email: 'sereno@muniaguasverdes.gob.pe' },
];

// Alfabeto sin caracteres ambiguos para evitar errores de transcripcion manual.
const ALFABETO = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%*-_';

function generarContrasena(longitud = 20) {
  const bytes = crypto.randomBytes(longitud);
  let salida = '';
  for (let i = 0; i < longitud; i++) {
    salida += ALFABETO[bytes[i] % ALFABETO.length];
  }
  return salida;
}

(async () => {
  const cliente = new Client({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await cliente.connect();

  const credenciales = [];
  for (const c of CLIENTES) {
    const { dni, rol, email } = c;
    const password = generarContrasena();
    const hash = bcrypt.hashSync(password, 12);
    await cliente.query('UPDATE usuarios SET password_hash = $1 WHERE dni = $2', [hash, dni]);
    credenciales.push({ dni, rol, email, password });
    console.log(`[ok] ${dni} (${rol}) rotado`);
  }

  const revocados = await cliente.query(
    'UPDATE refresh_tokens SET revocado = TRUE WHERE revocado = FALSE RETURNING id',
  );
  console.log(`[ok] ${revocados.rowCount} refresh token(s) activo(s) revocados`);

  await cliente.end();

  // Credenciales reales: solo en disco local, nunca en git.
  const destino = path.resolve(RAIZ_BACKEND, '..', 'database', 'CREDENCIALES_LOCALES.txt');
  fs.writeFileSync(
    destino,
    [
      'CREDENCIALES OPERATIVAS - ARCHIVO LOCAL, NO SUBIR A GIT',
      `Generado: ${new Date().toISOString()}`,
      '',
      ...credenciales.map((c) => `DNI ${c.dni} (${c.rol})\n  email: ${c.email}\n  password: ${c.password}\n`),
      'Si se pierde o se filtra: cambiar la contrasena con',
      '  UPDATE usuarios SET password_hash = $1 WHERE dni = $2',
      'generando el hash con bcryptjs (cost 12).',
      '',
    ].join('\n'),
    { encoding: 'utf8', mode: 0o600 },
  );
  console.log(`[ok] credenciales escritas en ${destino}`);
})().catch((e) => {
  console.error('[error]', e.message);
  process.exit(1);
});