import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import request from 'supertest';
import * as bcrypt from 'bcryptjs';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';

describe('Sprint 6 estadisticas (e2e)', () => {
  let app: INestApplication;
  let ds: DataSource;
  const ADMIN = { dni: '99999995', rol: 'ADMIN', pass: 'e2e-s6-1' };
  const SERENO = { dni: '99999994', rol: 'SERENO', pass: 'e2e-s6-2' };
  const DIRECTIVO = { dni: '99999993', rol: 'DIRECTIVO', pass: 'e2e-s6-3' };
  const CIUDADANO = { dni: '99999992', rol: 'CIUDADANO', pass: 'e2e-s6-4' };
  const OPERADOR = { dni: '99999991', rol: 'OPERADOR', pass: 'e2e-s6-5' };

  async function login(dni: string, pass: string) {
    const res = await request(app.getHttpServer()).post('/api/v1/auth/login').send({ dni, password: pass });
    return res.body.accessToken;
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    (app as NestExpressApplication).setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
    ds = moduleRef.get(DataSource);
    for (const u of [ADMIN, SERENO, DIRECTIVO, CIUDADANO, OPERADOR]) {
      const hash = bcrypt.hashSync(u.pass, 12);
      await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'E2E6', 'Test', $3, $2, (SELECT id FROM roles WHERE nombre = $4))`,
        [u.dni, hash, `${u.dni}@e2e6.local`, u.rol],
      );
    }
  });

  afterAll(async () => {
    await ds.query(`DELETE FROM usuarios WHERE dni IN ('99999995','99999994','99999993','99999992','99999991')`);
    await app.close();
  });

  it('sin token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/v1/incidencias/estadisticas').expect(401);
  });

  for (const r of [ADMIN, OPERADOR, DIRECTIVO]) {
    it(`${r.rol} -> 200`, async () => {
      const t = await login(r.dni, r.pass);
      await request(app.getHttpServer()).get('/api/v1/incidencias/estadisticas').set('Authorization', `Bearer ${t}`).expect(200);
    });
  }
  for (const r of [SERENO, CIUDADANO]) {
    it(`${r.rol} -> 403`, async () => {
      const t = await login(r.dni, r.pass);
      await request(app.getHttpServer()).get('/api/v1/incidencias/estadisticas').set('Authorization', `Bearer ${t}`).expect(403);
    });
  }

  it('ruta zonas-calor antes de :id (orden)', async () => {
    const t = await login(ADMIN.dni, ADMIN.pass);
    await request(app.getHttpServer()).get('/api/v1/incidencias/zonas-calor').set('Authorization', `Bearer ${t}`).expect(200);
  });
});
