import { ExecutionContext } from '@nestjs/common';
import { RateLimitGuard } from '../src/common/guards/rate-limit.guard';

function mockReq(ip?: string, deviceId?: string) {
  return {
    ip,
    headers: deviceId ? { 'x-device-id': deviceId } : {},
  } as unknown as Request;
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

describe('RateLimitGuard', () => {
  const guard = new RateLimitGuard();

  beforeEach(() => {
    guard.reset();
  });

  it('permite peticiones por debajo del limite de IP', () => {
    const req = mockReq('1.1.1.1', 'devA');
    const res = mockRes();
    for (let i = 0; i < 10; i++) {
      expect(guard.canActivate(mockCtx(req, res))).toBe(true);
    }
  });

  it('bloquea la 11a peticion por IP (limite 10/10min)', () => {
    const req = mockReq('2.2.2.2', 'devB');
    const res = mockRes();
    for (let i = 0; i < 10; i++) {
      expect(guard.canActivate(mockCtx(req, res))).toBe(true);
    }
    expect(guard.canActivate(mockCtx(req, res))).toBe(false);
    expect(res.getHeaders()['retry-after']).toBeTruthy();
  });

  it('bloquea la 4a peticion por dispositivo (limite 3/10min)', () => {
    const req = mockReq('3.3.3.3', 'devC');
    const res = mockRes();
    for (let i = 0; i < 3; i++) {
      expect(guard.canActivate(mockCtx(req, res))).toBe(true);
    }
    expect(guard.canActivate(mockCtx(req, res))).toBe(false);
  });

  it('dos clientes distintos no comparten contador de IP', () => {
    const res1 = mockRes();
    const res2 = mockRes();
    const reqA = mockReq('10.0.0.1', 'devA');
    for (let i = 0; i < 10; i++) {
      expect(guard.canActivate(mockCtx(reqA, res1))).toBe(true);
    }
    const reqB = mockReq('10.0.0.2', 'devB');
    for (let i = 0; i < 5; i++) {
      expect(guard.canActivate(mockCtx(reqB, res2))).toBe(true);
    }
    expect(guard.canActivate(mockCtx(reqA, res1))).toBe(false);
  });

  it('dos dispositivos distintos no comparten contador de dispositivo', () => {
    const res = mockRes();
    const req1 = mockReq('10.0.0.5', 'devX');
    const req2 = mockReq('10.0.0.5', 'devY');
    for (let i = 0; i < 3; i++) {
      expect(guard.canActivate(mockCtx(req1, res))).toBe(true);
    }
    expect(guard.canActivate(mockCtx(req1, res))).toBe(false);
    for (let i = 0; i < 3; i++) {
      expect(guard.canActivate(mockCtx(req2, res))).toBe(true);
    }
    expect(guard.canActivate(mockCtx(req2, res))).toBe(false);
  });
});
