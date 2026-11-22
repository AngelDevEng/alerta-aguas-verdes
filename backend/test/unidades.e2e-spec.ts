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
  // Ids de lo que ESTE archivo inserta; el cleanup borra solo esos.
  const userIds: string[] = [];

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
      const [row] = await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'U', 'Test', $3, $2, (SELECT id FROM roles WHERE nombre = $4))
         RETURNING id`,
        [u.dni, hash, `${u.dni}@u.local`, u.rol],
      );
      userIds.push(row.id);
    }
    tokenAdmin = await login(ADMIN.dni, ADMIN.pass);
  });

  afterAll(async () => {
    // Solo la unidad y los usuarios que este archivo inserto (por id).
    if (unidadId) {
      await ds.query(`DELETE FROM ubicaciones_unidad WHERE unidad_id = $1`, [unidadId]);
      await ds.query(`DELETE FROM unidades_serenazgo WHERE id = $1`, [unidadId]);
    }
    if (userIds.length) {
      await ds.query(`DELETE FROM usuarios WHERE id = ANY($1::uuid[])`, [userIds]);
    }
    await app.close();
  });

  it('POST crea unidad', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/unidades')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ codigo: 'TEST-U-E2E', tipo: 'MOTOCICLETA', placa: 'TST-001' })
      .expect(201);
    unidadId = res.body.id;
  });

  it('GET lista unidades', async () => {
    await request(app.getHttpServer()).get('/api/v1/unidades').set('Authorization', `Bearer ${tokenAdmin}`).expect(200);
  });

  it('GET /unidades/verificar (publico) devuelve solo codigo, tipo y placa', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/unidades/verificar?placa=TST-001')
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    const u = res.body[0];
    expect(u.codigo).toBe('TEST-U-E2E');
    expect(u.placa).toBe('TST-001');
    expect(u.tipo).toBe('MOTOCICLETA');
    // No expone estado, responsable ni ubicacion.
    expect(u.estado).toBeUndefined();
    expect(u.responsableId).toBeUndefined();
    expect(u.latitud).toBeUndefined();
    expect(u.longitud).toBeUndefined();
    expect(u.ultimaActualizacion).toBeUndefined();
  });

  it('GET /unidades/verificar exige placa', async () => {
    await request(app.getHttpServer()).get('/api/v1/unidades/verificar').expect(400);
  });

  it('GET /unidades (lista completa) exige rol: sin token 401', async () => {
    await request(app.getHttpServer()).get('/api/v1/unidades').expect(401);
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

  it('cercanas devuelve unidades DISPONIBLES creadas por este test', async () => {
    // Se crea una unidad propia, se marca DISPONIBLE y se le asigna ubicacion;
    // asi el test no depende de SER-01 ni de datos sembrados.
    const s = Date.now().toString().slice(-6);
    const [unidad] = await ds.query(
      `INSERT INTO unidades_serenazgo (codigo, tipo, placa, estado)
       VALUES ($1, 'PIE', $2, 'DISPONIBLE') RETURNING id`,
      [`test-e2e-$s`, `TST-$s`],
    );
    try {
      await ds.query(
        `INSERT INTO ubicaciones_unidad (unidad_id, ubicacion)
         VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography)`,
        [unidad.id, -80.3, -3.5],
      );

      const r = await request(app.getHttpServer())
        .get(`/api/v1/unidades/cercanas?lon=-80.3&lat=-3.5&radio=1000`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .expect(200);
      expect(Array.isArray(r.body)).toBe(true);
      expect(r.body.some((u: any) => u.id === unidad.id)).toBe(true);
    } finally {
      await ds.query(`DELETE FROM ubicaciones_unidad WHERE unidad_id = $1`, [unidad.id]);
      await ds.query(`DELETE FROM unidades_serenazgo WHERE id = $1`, [unidad.id]);
    }
  });
});
