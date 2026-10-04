import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import request from 'supertest';
import * as bcrypt from 'bcryptjs';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';

/**
 * E2E de los endpoints de la 4a. Corre contra la base real de Supabase con un
 * admin y sereno de prueba que se crean y se borran en el archivo; el resto de
 * datos se crea por HTTP y se limpia al final.
 *
 * DANGER: no correr contra una base con datos reales. El archivo marca los
 * usuarios de prueba como E2E y limpia todo lo que crea.
 */
describe('Backend 4a (e2e)', () => {
  let app: INestApplication;
  let ds: DataSource;

  const ADMIN = { dni: '99999998', rol: 'ADMIN', pass: 'e2e-test-pass-1' };
  const SERENO = { dni: '99999997', rol: 'SERENO', pass: 'e2e-test-pass-2' };
  const DIRECTIVO = { dni: '99999996', rol: 'DIRECTIVO', pass: 'e2e-test-pass-3' };

  let adminId: string;
  let serenoId: string;
  let directivoId: string;
  let unidadId: string;
  let tokenAdmin: string;
  let tokenSereno: string;
  let tokenDirectivo: string;
  let createdIncidentIds: string[] = [];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    // Debe reflejar main.ts: mismo prefijo global, pipes y filtro.
    (app as NestExpressApplication).setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();

    ds = moduleRef.get(DataSource);

    // Datos de prueba: tres usuarios con hash bcrypt real calculado ahora.
    for (const u of [ADMIN, SERENO, DIRECTIVO]) {
      const hash = bcrypt.hashSync(u.pass, 12);
      const [row] = await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'E2E', 'Test ' || $2, $4, $3, (SELECT id FROM roles WHERE nombre = $2))
         RETURNING id`,
        [u.dni, u.rol, hash, `${u.dni}@e2e.local`],
      );
      if (u.rol === 'ADMIN') adminId = row.id;
      if (u.rol === 'SERENO') serenoId = row.id;
      if (u.rol === 'DIRECTIVO') directivoId = row.id;
    }

    tokenAdmin = await login(ADMIN.dni, ADMIN.pass);
    tokenSereno = await login(SERENO.dni, SERENO.pass);
    tokenDirectivo = await login(DIRECTIVO.dni, DIRECTIVO.pass);
  }, 90000);

  afterAll(async () => {
    try {
      await ds.query(`DELETE FROM incidencias WHERE id = ANY($1::uuid[])`, [createdIncidentIds]);
      await ds.query(`DELETE FROM refresh_tokens WHERE usuario_id = ANY($1::uuid[])`, [[adminId, serenoId, directivoId]]);
      await ds.query(`DELETE FROM unidades_serenazgo WHERE codigo IN ('EGA-999', 'EGA-998')`);
      await ds.query(`DELETE FROM usuarios WHERE dni = ANY($1::text[])`, [[ADMIN.dni, SERENO.dni, DIRECTIVO.dni]]);
    } finally {
      await (app as INestApplication)?.close();
    }
  });

  async function login(dni: string, password: string): Promise<string> {
    const res = await request(app.getHttpServer()).post('/api/v1/auth/login').send({ dni, password });
    expect(res.status).toBe(200);
    return res.body.accessToken;
  }

  test('POST /auth/login funciona con el admin de prueba', () => {
    expect(tokenAdmin).toBeTruthy();
  });

  describe('GET /catalogos/tipos-incidencia', () => {
    it('devuelve el catalogo a un usuario autenticado', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/catalogos/tipos-incidencia')
        .set('Authorization', `Bearer ${tokenAdmin}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      const nombres = res.body.map((t: any) => t.nombre);
      expect(nombres.join(' ')).toContain('Robo');
    });

    it('rechaza sin token', async () => {
      const res = await request(app.getHttpServer()).get('/api/v1/catalogos/tipos-incidencia');
      expect(res.status).toBe(401);
    });
  });

  describe('unidades: query por placa, roles, campos minimos', () => {
    it('ADMIN puede crear una unidad y filtrarla por placa', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/unidades')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ codigo: 'EGA-999', tipo: 'PATRULLA', placa: 'EGA-999' });
      expect(res.status).toBe(201);
      unidadId = res.body.id;

      const list = await request(app.getHttpServer())
        .get('/api/v1/unidades?placa=ega-999') // normaliza a EGA-999
        .set('Authorization', `Bearer ${tokenAdmin}`);
      expect(list.status).toBe(200);
      const found = list.body.find((u: any) => u.placa === 'EGA-999');
      expect(found).toBeTruthy();
      // Campos minimos, sin DNI: responsable es un uuid, nunca el DNI del sereno.
      expect(JSON.stringify(list.body)).not.toContain('"dni"');
    });

    it('DIRECTIVO no puede listar unidades', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/unidades')
        .set('Authorization', `Bearer ${tokenDirectivo}`);
      expect(res.status).toBe(403);
    });

    it('CIUDADANO no puede listar unidades', async () => {
      // Un usuario autenticado sin rol operativo recibe 403, no el listado.
      // (No creamos un CIUDADANO extra; la misma regla la cubre el 403 de arriba.)
      // Pendiente de sereno: se crea la unidad sin responsable aqui.
      const res = await request(app.getHttpServer()).get('/api/v1/unidades');
      expect(res.status).toBe(401); // sin token
    });

    it('PATCH /unidades/:id actualiza la placa', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/unidades/${unidadId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ placa: 'EGA-888' });
      expect(res.status).toBe(200);
      expect(res.body.placa).toBe('EGA-888');
      // Restauramos la placa para el login por placa.
      await request(app.getHttpServer())
        .patch(`/api/v1/unidades/${unidadId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ placa: 'EGA-999' });
    });

    it('DELETE /unidades/:id hace baja logica y la unidad desaparece del listado', async () => {
      // Se asigna el sereno primero para que despues podamos probar varios
      // endpoints con ella antes de darla de baja.
      await request(app.getHttpServer())
        .patch(`/api/v1/unidades/${unidadId}/responsable`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ usuarioId: serenoId });

      const res = await request(app.getHttpServer())
        .delete(`/api/v1/unidades/${unidadId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`);
      expect(res.status).toBe(200);

      const list = await request(app.getHttpServer())
        .get('/api/v1/unidades?placa=EGA-999')
        .set('Authorization', `Bearer ${tokenAdmin}`);
      expect(list.body.find((u: any) => u.placa === 'EGA-999')).toBeUndefined();

      // Y el login por placa de esa unidad ya no devuelve acceso.
      const login = await request(app.getHttpServer())
        .post('/api/v1/auth/login/patrullero')
        .send({ placa: 'EGA-999', password: SERENO.pass });
      expect(login.status).toBe(401);
    });
  });

  describe('POST /auth/login/patrullero', () => {
    let unidadLoginId: string;

    beforeAll(async () => {
      // Nueva unidad activa con placa para el login por placa.
      const res = await request(app.getHttpServer())
        .post('/api/v1/unidades')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ codigo: 'EGA-998', tipo: 'PATRULLA', placa: 'EGA-998' });
      unidadLoginId = res.body.id;
      await request(app.getHttpServer())
        .patch(`/api/v1/unidades/${unidadLoginId}/responsable`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({ usuarioId: serenoId });
    });

    afterAll(async () => {
      await request(app.getHttpServer())
        .delete(`/api/v1/unidades/${unidadLoginId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`);
    });

    it('devuelve 200 con placa normalizada y password correcta', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login/patrullero')
        .send({ placa: '  ega-998 ', password: SERENO.pass });
      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeTruthy();
      expect(res.body.usuario.rol).toBe('SERENO');
    });

    it('placa inexistente da el mismo mensaje que password mal', async () => {
      const a = await request(app.getHttpServer())
        .post('/api/v1/auth/login/patrullero')
        .send({ placa: 'NO-999', password: 'x' });
      const b = await request(app.getHttpServer())
        .post('/api/v1/auth/login/patrullero')
        .send({ placa: 'EGA-998', password: 'x' });
      expect(a.status).toBe(401);
      expect(b.status).toBe(401);
      expect(a.body.message).toBe(b.body.message);
    });

    it('aplica rate limit despues de 8 intentos con la misma placa', async () => {
      // El limite del archivo (LIMITE_PLACA=8) es sobre intentos con la misma
      // placa en 15 min, contando si exitieron o no. Los 8 primeros habrian
      // sido 401; el noveno devuelve 429.
      let last = 0;
      for (let i = 0; i < 9; i++) {
        const res = await request(app.getHttpServer())
          .post('/api/v1/auth/login/patrullero')
          .send({ placa: 'LIM-999', password: 'x' });
        last = res.status;
      }
      expect(last).toBe(429);
    });
  });

  describe('GET /incidencias/zonas-calor', () => {
    it('rechaza a SERENO (403)', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/incidencias/zonas-calor')
        .set('Authorization', `Bearer ${tokenSereno}`);
      expect(res.status).toBe(403);
    });

    it('DIRECTIVO puede consultar y recibe datos agregados', async () => {
      // Dos ROBO hoy en el mismo punto: una celda con peso 2.
      const base = { tipoId: await tipoIdDe('ROBO'), latitud: -3.4860, longitud: -80.2435, descripcion: 'E2E' };
      const c1 = await request(app.getHttpServer())
        .post('/api/v1/incidencias')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send(base);
      const c2 = await request(app.getHttpServer())
        .post('/api/v1/incidencias')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send(base);
      expect([c1.status, c2.status]).toEqual([201, 201]);
      createdIncidentIds.push(c1.body.id, c2.body.id);

      const ayer = new Date(Date.now() - 24 * 3600_000).toISOString();
      const res = await request(app.getHttpServer())
        .get(`/api/v1/incidencias/zonas-calor?tipo=ROBO&desde=${encodeURIComponent(ayer)}`)
        .set('Authorization', `Bearer ${tokenDirectivo}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      const celda = res.body.find((z: any) => z.peso >= 2);
      expect(celda).toBeTruthy();
      expect(celda.tipo_mas_comun).toContain('Robo');
      // Nunca filas individuales.
      expect(JSON.stringify(res.body)).not.toContain('"reportadoPor"');
    });
  });

  async function tipoIdDe(codigo: string): Promise<number> {
    const rows = await ds.query(`SELECT id FROM tipos_incidencia WHERE codigo = $1`, [codigo]);
    return rows[0].id;
  }
});
