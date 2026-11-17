import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { Request, Response } from 'express';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const IP_WINDOW_MS = 600_000;
const IP_MAX_REQUESTS = 10;
const DEVICE_WINDOW_MS = 600_000;
const DEVICE_MAX_REQUESTS = 3;

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly ipStore = new Map<string, RateLimitEntry>();
  private readonly deviceStore = new Map<string, RateLimitEntry>();

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const res = ctx.switchToHttp().getResponse<Response>();

    const ipMax = Number(process.env.RATE_LIMIT_IP_MAX ?? IP_MAX_REQUESTS);
    const ipWindow = Number(process.env.RATE_LIMIT_IP_WINDOW_MS ?? IP_WINDOW_MS);
    this.checkLimit(this.ipStore, req.ip ?? 'unknown', ipMax, ipWindow, res);

    const deviceId = req.headers['x-device-id'] as string | undefined;
    if (deviceId) {
      const deviceMax = Number(process.env.RATE_LIMIT_DEVICE_MAX ?? DEVICE_MAX_REQUESTS);
      const deviceWindow = Number(process.env.RATE_LIMIT_DEVICE_WINDOW_MS ?? DEVICE_WINDOW_MS);
      this.checkLimit(this.deviceStore, deviceId, deviceMax, deviceWindow, res);
    }

    return true;
  }

  private checkLimit(
    store: Map<string, RateLimitEntry>,
    key: string,
    maxRequests: number,
    windowMs: number,
    res: Response,
  ) {
    const entry = store.get(key);
    if (!entry || Date.now() > entry.resetAt) {
      store.set(key, { count: 1, resetAt: Date.now() + windowMs });
      return;
    }

    entry.count += 1;
    if (entry.count > maxRequests) {
      const retryAfter = Math.ceil((entry.resetAt - Date.now()) / 1000);
      res.setHeader('Retry-After', String(retryAfter));
      throw new HttpException('Demasiadas solicitudes, intente de nuevo mas tarde', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  reset() {
    this.ipStore.clear();
    this.deviceStore.clear();
  }
}