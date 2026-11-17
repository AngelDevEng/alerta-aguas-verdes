import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { io, Socket } from 'socket.io-client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { RateLimitGuard } from '../src/common/guards/rate-limit.guard';

describe('Alertas SOS (e2e)', () => {
  let app: INestApplication;
  let ds: DataSource;
  let rateLimit: RateLimitGuard;

  const DISPOSITIVO = `e2e-sos-${Date.now()}`;
  const ADMIN = { dni: '99999980', rol: 'ADMIN', pass: 'e2e-sos-1' };
  const SERENO = { dni: '99999981', rol: 'SERENO', pass: 'e2e-sos-2' };
  const ids: string[] = [];

  async function login(dni: string, pass: string) {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ dni, password: pass });
    return res.body.accessToken as string;
  }

  function crearAlerta(dispositivo: string, extra: Record<string, unknown> = {}) {
    return request(app.getHttpServer())
      .post('/api/v1/alertas')
      .set('X-Device-Id', dispositivo)
      .send({
        latitud: -3.4825,
        longitud: -80.245,
        telefono: '51900000000',
        direccion: 'Alerta e2e',
        origen: 'APP',
        ...extra,
      });
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    (app as NestExpressApplication).setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.listen(0);
    ds = moduleRef.get(DataSource);
    rateLimit = moduleRef.get(RateLimitGuard);

    for (const u of [ADMIN, SERENO]) {
      const hash = bcrypt.hashSync(u.pass, 12);
      await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'E2E', 'Sos', $3, $2, (SELECT id FROM roles WHERE nombre = $4))`,
        [u.dni, hash, `${u.dni}@e2e-sos.local`, u.rol],
      );
    }
  });

  afterAll(async () => {
    if (ids.length) {
      await ds.query(`DELETE FROM alertas WHERE id = ANY($1::uuid[])`, [ids]);
    }
    await ds.query(`DELETE FROM incidencias WHERE referencia = 'Alerta e2e'`);
    await ds.query(`DELETE FROM usuarios WHERE dni IN ('99999980','99999981')`);
    await app.close();
  });

  beforeEach(() => {
    rateLimit.reset();
  });

  it('POST /alertas conserva los campos actuales y añade sessionToken', async () => {
    const res = await crearAlerta(DISPOSITIVO);
    expect(res.status).toBe(201);
    expect(typeof res.body.id).toBe('string');
    expect(res.body.estado).toBe('ACTIVA');
    expect(res.body.telefono).toBe('51900000000');
    expect(res.body.creadaEn).toBeTruthy();
    expect(typeof res.body.sessionToken).toBe('string');
    expect(res.body.sessionToken.length).toBeGreaterThan(20);
    ids.push(res.body.id);
  });

  it('GET /alertas/:id/seguimiento exige X-Session-Token', async () => {
    const res = await crearAlerta(`${DISPOSITIVO}-seg`);
    ids.push(res.body.id);

    const sinToken = await request(app.getHttpServer()).get(`/api/v1/alertas/${res.body.id}/seguimiento`);
    expect(sinToken.status).toBe(401);

    const conToken = await request(app.getHttpServer())
      .get(`/api/v1/alertas/${res.body.id}/seguimiento`)
      .set('X-Session-Token', res.body.sessionToken);
    expect(conToken.status).toBe(200);
    expect(conToken.body.alerta.id).toBe(res.body.id);
    expect(conToken.body.alerta.estado).toBe('ACTIVA');
    expect(Array.isArray(conToken.body.ciudadano.ubicaciones)).toBe(true);
    expect(conToken.body.sereno).toBeNull();
  });

  it('un token invalido no sirve para seguimiento', async () => {
    const res = await crearAlerta(`${DISPOSITIVO}-bad`);
    ids.push(res.body.id);

    const r = await request(app.getHttpServer())
      .get(`/api/v1/alertas/${res.body.id}/seguimiento`)
      .set('X-Session-Token', 'no-es-un-token-valido');
    expect(r.status).toBe(401);
  });

  it('una sola SOS viva por dispositivo: la segunda devuelve la primera con token nuevo', async () => {
    const dispositivo = `${DISPOSITIVO}-dedupe`;
    const primero = await crearAlerta(dispositivo);
    ids.push(primero.body.id);
    const segundo = await crearAlerta(dispositivo);

    expect(segundo.status).toBe(201);
    expect(segundo.body.id).toBe(primero.body.id);
    expect(segundo.body.sessionToken).not.toBe(primero.body.sessionToken);

    const [{ total }] = await ds.query(
      `SELECT count(*)::int AS total FROM alertas
        WHERE dispositivo_id = $1 AND estado IN ('ACTIVA','ACEPTADA')`,
      [dispositivo],
    );
    expect(total).toBe(1);
  });

  it('nueva_alerta_sos llega a central y a serenos', async () => {
    const adminToken = await login(ADMIN.dni, ADMIN.pass);
    const serenoToken = await login(SERENO.dni, SERENO.pass);
    const port = (app.getHttpServer().address() as any).port;

    const admin: Socket = io(`http://127.0.0.1:${port}/ws`, {
      transports: ['websocket'],
      auth: { token: adminToken },
      reconnection: false,
    });
    const sereno: Socket = io(`http://127.0.0.1:${port}/ws`, {
      transports: ['websocket'],
      auth: { token: serenoToken },
      reconnection: false,
    });

    const esperaConexion = (s: Socket) =>
      new Promise<void>((resolve, reject) => {
        const t = setTimeout(() => reject(new Error('timeout conectando socket')), 5000);
        s.on('connect', () => { clearTimeout(t); resolve(); });
        s.on('connect_error', (e) => { clearTimeout(t); reject(e); });
      });

    try {
      await Promise.all([esperaConexion(admin), esperaConexion(sereno)]);

      const eventos: { admin: any[]; sereno: any[] } = { admin: [], sereno: [] };
      admin.on('nueva_alerta_sos', (d) => eventos.admin.push(d));
      sereno.on('nueva_alerta_sos', (d) => eventos.sereno.push(d));

      const res = await crearAlerta(`${DISPOSITIVO}-ws`);
      ids.push(res.body.id);

      await new Promise((r) => setTimeout(r, 500));
      expect(eventos.admin.some((e) => e.id === res.body.id)).toBe(true);
      expect(eventos.sereno.some((e) => e.id === res.body.id)).toBe(true);
    } finally {
      admin.disconnect();
      sereno.disconnect();
    }
  });

  it('rate limit por IP: la sexta peticion recibe 429', async () => {
    const dispositivo = `${DISPOSITIVO}-rate`;
    for (let i = 0; i < 5; i++) {
      const res = await crearAlerta(dispositivo, { latitud: -3.4825 - i * 0.001 });
      expect(res.status).toBe(201);
      ids.push(res.body.id);
    }

    const sexto = await crearAlerta(`${dispositivo}-6`);
    expect(sexto.status).toBe(429);
    expect(sexto.headers['retry-after']).toBeTruthy();
  });
});