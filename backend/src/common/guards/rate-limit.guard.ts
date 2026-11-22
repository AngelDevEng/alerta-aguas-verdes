import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable, Logger, Optional } from '@nestjs/common';
import { createHash } from 'crypto';
import { DataSource } from 'typeorm';
import { Request, Response } from 'express';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const IP_WINDOW_MS = 600_000;
// 20 y no 10: en redes moviles (CGNAT) muchos vecinos comparten la misma IP
// publica. Un limite bajo castiga a usuarios inocentes; el limite por
// dispositivo (abajo) es el que de verdad frena el abuso.
const IP_MAX_REQUESTS = 20;
const DEVICE_WINDOW_MS = 600_000;
const DEVICE_MAX_REQUESTS = 3;

/** SHA-256 hex de la `Idempotency-Key`, igual que en el servicio. */
function hashClave(clave: string): string {
  return createHash('sha256').update(clave).digest('hex');
}

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly logger = new Logger(RateLimitGuard.name);
  private readonly ipStore = new Map<string, RateLimitEntry>();
  private readonly deviceStore = new Map<string, RateLimitEntry>();

  // DataSource es opcional: si no esta disponible (p. ej. en un test unitario
  // que no arranca TypeORM) el guard sigue funcionando sin la exencion
  // idempotente.
  constructor(@Optional() private readonly ds?: DataSource) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request>();
    const res = ctx.switchToHttp().getResponse<Response>();

    const ipMax = Number(process.env.RATE_LIMIT_IP_MAX ?? IP_MAX_REQUESTS);
    const ipWindow = Number(process.env.RATE_LIMIT_IP_WINDOW_MS ?? IP_WINDOW_MS);
    this.checkLimit(this.ipStore, req.ip ?? 'unknown', ipMax, ipWindow, res);

    // Un reintento idempotente (misma clave Y mismo dispositivo) NO cuenta
    // contra el limite de dispositivo: es la misma SOS, no un abuso. Una clave
    // nueva si cuenta. El limite por IP se sigue aplicando siempre.
    const dispositivo = req.headers['x-device-id'] as string | undefined;
    const idempotencyKey = req.headers['idempotency-key'] as string | undefined;
    const esReintento = await this.esReintentoIdempotente(idempotencyKey, dispositivo);

    if (dispositivo && !esReintento) {
      const deviceMax = Number(process.env.RATE_LIMIT_DEVICE_MAX ?? DEVICE_MAX_REQUESTS);
      const deviceWindow = Number(process.env.RATE_LIMIT_DEVICE_WINDOW_MS ?? DEVICE_WINDOW_MS);
      this.checkLimit(this.deviceStore, dispositivo, deviceMax, deviceWindow, res);
    }

    return true;
  }

  /**
   * La clave ya existe y pertenece al mismo dispositivo: es un reintento, no
   * un abuso. Si la tabla no existe (SQLSTATE 42P01) se registra una
   * advertencia y se trata como "no reintento" (el guard no rompe el flujo).
   * Cualquier otro error se registra con detalle y tambien se degrada.
   */
  private async esReintentoIdempotente(
    clave: string | undefined,
    dispositivo: string | undefined,
  ): Promise<boolean> {
    if (!clave || !dispositivo || !this.ds) return false;
    try {
      const rows = await this.ds.query(
        `SELECT 1 FROM alertas_idempotencia
          WHERE clave_hash = $1 AND dispositivo_id = $2
          LIMIT 1`,
        [hashClave(clave), dispositivo],
      );
      return Array.isArray(rows) && rows.length > 0;
    } catch (e: any) {
      if (e?.code === '42P01') {
        this.logger.warn(
          'Tabla alertas_idempotencia no existe (SQLSTATE 42P01); el guard no puede detectar reintentos idempotentes. Aplica la migracion 09.',
        );
      } else {
        this.logger.error(
          `Fallo al consultar alertas_idempotencia en el rate limit; se trata como no reintento: ${e?.message ?? e}`,
          e?.stack,
        );
      }
      return false;
    }
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