import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import request from 'supertest';
import * as bcrypt from 'bcryptjs';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';

describe('Unidades (e2e)', () => {
  let app: INestApplication;
  let ds: DataSource;
  const ADMIN = { dni: '99999980', rol: 'ADMIN', pass: 'e2e-u-1' };
  const OPERADOR = { dni: '99999979', rol: 'OPERADOR', pass: 'e2e-u-2' };
  let tokenAdmin: string;
  let unidadId: string;

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
    for (const u of [ADMIN, OPERADOR]) {
      const hash = bcrypt.hashSync(u.pass, 12);
      await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'U', 'Test', $3, $2, (SELECT id FROM roles WHERE nombre = $4))`,
        [u.dni, hash, `${u.dni}@u.local`, u.rol],
      );
    }
    tokenAdmin = await login(ADMIN.dni, ADMIN.pass);
  });

  afterAll(async () => {
    await ds.query(`DELETE FROM ubicaciones_unidad WHERE unidad_id IN (SELECT id FROM unidades_serenazgo WHERE codigo='TEST-U-E2E')`);
    await ds.query(`DELETE FROM unidades_serenazgo WHERE codigo='TEST-U-E2E'`);
    await ds.query(`DELETE FROM usuarios WHERE dni IN ('99999980','99999979')`);
    await app.close();
  });

  it('POST crea unidad', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/unidades')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ codigo: 'TEST-U-E2E', tipo: 'MOTO', placa: 'TST-001' })
      .expect(201);
    unidadId = res.body.id;
  });

  it('GET lista unidades', async () => {
    await request(app.getHttpServer()).get('/api/v1/unidades').set('Authorization', `Bearer ${tokenAdmin}`).expect(200);
  });

  it('POST ubicacion guarda y rastro la devuelve', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/unidades/${unidadId}/ubicaciones`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ latitud: -3.5, longitud: -80.3 })
      .expect(201);
    const r = await request(app.getHttpServer())
      .get(`/api/v1/unidades/${unidadId}/rastro`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);
    expect(Array.isArray(r.body)).toBe(true);
  });

  it('cercanas devuelve distancia en metros', async () => {
    const r = await request(app.getHttpServer())
      .get(`/api/v1/unidades/cercanas?lon=-80.3&lat=-3.5&radio=1000`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);
    expect(Array.isArray(r.body)).toBe(true);
  });
});
