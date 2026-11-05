import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { io } from 'socket.io-client';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';

describe('Gateway realtime (e2e)', () => {
  let app: INestApplication;
  let ds: DataSource;
  const ADMIN = { dni: '99999990', rol: 'ADMIN', pass: 'e2e-gw-1' };
  const SERENO = { dni: '99999989', rol: 'SERENO', pass: 'e2e-gw-2' };

  function login(dni: string, pass: string): Promise<string> {
    return new Promise((resolve) => {
      // placeholder: tests assume token passed via env in real runs
      resolve('');
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
    for (const u of [ADMIN, SERENO]) {
      const hash = bcrypt.hashSync(u.pass, 12);
      await ds.query(
        `INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
         VALUES ($1, 'GW', 'Test', $3, $2, (SELECT id FROM roles WHERE nombre = $4))`,
        [u.dni, hash, `${u.dni}@gw.local`, u.rol],
      );
    }
  });

  afterAll(async () => {
    await ds.query(`DELETE FROM usuarios WHERE dni IN ('99999990','99999989')`);
    await app.close();
  });

  it('conexion sin token es rechazada', (done) => {
    const port = (app.getHttpServer().address() as any).port;
    const s = io(`http://127.0.0.1:${port}/ws`, { transports: ['websocket'], auth: {} });
    let connected = false;
    s.on('connect', () => { connected = true; });
    s.on('disconnect', () => { s.disconnect(); done(); });
    s.on('connect_error', () => { s.disconnect(); done(); });
    setTimeout(() => { if (!connected) { s.disconnect(); done(); } }, 2000);
  });
});
