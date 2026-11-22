import { createHash } from 'crypto';
import { ExecutionContext } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { RateLimitGuard } from '../src/common/guards/rate-limit.guard';

function hashClave(clave: string): string {
  return createHash('sha256').update(clave).digest('hex');
}

function mockReq(ip?: string, deviceId?: string, idempotencyKey?: string) {
  const headers: Record<string, string> = {};
  if (deviceId) headers['x-device-id'] = deviceId;
  if (idempotencyKey) headers['idempotency-key'] = idempotencyKey;
  return { ip, headers } as unknown as Request;
}

function mockRes() {
  const headers: Record<string, string> = {};
  return {
    setHeader: (key: string, value: string) => {
      headers[key] = value;
    },
    getHeaders: () => headers,
  } as unknown as Response;
}

function mockCtx(req: Request, res: Response) {
  return {
    switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
  } as unknown as ExecutionContext;
}

/**
 * DataSource falso: responde a la consulta de idempotencia segun el conjunto de
 * pares "hashClave:dispositivo" que se declara existentes. El guard solo usa
 * `query` para esa comprobacion.
 */
class DataSourceFake {
  constructor(private readonly existentes: Set<string>) {}

  query(_sql: string, params?: unknown[]): Promise<unknown[][]> {
    const hash = params?.[0] as string | undefined;
    const dispositivo = params?.[1] as string | undefined;
    if (hash != null && dispositivo != null && this.existentes.has(`${hash}:${dispositivo}`)) {
      return Promise.resolve([['?column?', 1]]);
    }
    return Promise.resolve([]);
  }
}

function guardCon(existentes: Set<string> = new Set()): RateLimitGuard {
  return new RateLimitGuard(new DataSourceFake(existentes) as unknown as DataSource);
}

describe('RateLimitGuard', () => {
  it('permite 20 peticiones por IP y bloquea la 21a', async () => {
    const guard = guardCon();
    guard.reset();
    const res = mockRes();
    // Dispositivo distinto en cada peticion para aislar el limite de IP.
    for (let i = 0; i < 20; i++) {
      const req = mockReq('1.1.1.1', `devA-${i}`);
      await expect(guard.canActivate(mockCtx(req, res))).resolves.toBe(true);
    }
    const req = mockReq('1.1.1.1', 'devA-20');
    await expect(guard.canActivate(mockCtx(req, res))).rejects.toThrow();
    expect(res.getHeaders()['retry-after']).toBeTruthy();
  });

  it('bloquea la 4a peticion por dispositivo (limite 3/10min)', async () => {
    const guard = guardCon();
    guard.reset();
    const req = mockReq('3.3.3.3', 'devC');
    const res = mockRes();
    for (let i = 0; i < 3; i++) {
      await expect(guard.canActivate(mockCtx(req, res))).resolves.toBe(true);
    }
    await expect(guard.canActivate(mockCtx(req, res))).rejects.toThrow();
  });

  it('un reintento idempotente (misma clave + mismo dispositivo) no cuenta contra el limite de dispositivo', async () => {
    const hash = hashClave('key-1');
    const guard = guardCon(new Set([`${hash}:devA`]));
    guard.reset();
    const req = mockReq('4.4.4.4', 'devA', 'key-1');
    const res = mockRes();
    // 10 > limite de dispositivo (3): si contara, la 4a fallaria.
    for (let i = 0; i < 10; i++) {
      await expect(guard.canActivate(mockCtx(req, res))).resolves.toBe(true);
    }
  });

  it('una clave que pertenece a OTRO dispositivo no exime del limite', async () => {
    const hash = hashClave('key-2');
    const guard = guardCon(new Set([`${hash}:otro`]));
    guard.reset();
    const req = mockReq('5.5.5.5', 'devZ', 'key-2');
    const res = mockRes();
    for (let i = 0; i < 3; i++) {
      await expect(guard.canActivate(mockCtx(req, res))).resolves.toBe(true);
    }
    await expect(guard.canActivate(mockCtx(req, res))).rejects.toThrow();
  });

  it('una clave nueva (no registrada) si cuenta contra el limite de dispositivo', async () => {
    const guard = guardCon();
    guard.reset();
    const res = mockRes();
    for (let i = 0; i < 3; i++) {
      const req = mockReq('6.6.6.6', 'devN', `key-nueva-${i}`);
      await expect(guard.canActivate(mockCtx(req, res))).resolves.toBe(true);
    }
    const ultimo = mockReq('6.6.6.6', 'devN', 'key-nueva-3');
    await expect(guard.canActivate(mockCtx(ultimo, res))).rejects.toThrow();
  });
});