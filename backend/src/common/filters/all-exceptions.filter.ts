import {
  ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Unica forma de error de toda la API (ver `common/dto/respuesta-error.dto.ts`).
 *
 * Ademas de estandarizar, evita que los errores de Postgres (violaciones de FK,
 * checks, duplicados) y los de multer (archivo muy grande, MIME inesperado) se
 * filtren al cliente como 500 con el detalle de la consulta.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(excepcion: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    const responder = (status: number, mensajes: string[]) => {
      const mensaje = mensajes[0] ?? 'Error interno del servidor';
      return res.status(status).json({
        success: false,
        statusCode: status,
        mensaje,
        message: mensaje,
        mensajes,
        ruta: req.url,
      });
    };

    if (excepcion instanceof HttpException) {
      const status = excepcion.getStatus();
      const cuerpo = excepcion.getResponse();
      const crudo =
        typeof cuerpo === 'string'
          ? cuerpo
          : ((cuerpo as { message?: string | string[] }).message ?? excepcion.message);
      const lista = (Array.isArray(crudo) ? crudo : [crudo]).map(String);
      return responder(status, lista.length ? lista : ['Error interno del servidor']);
    }

    const e = excepcion as { code?: string; message?: string };

    // Errores conocidos de Postgres con equivalente HTTP claro
    const porCodigo: Record<string, [HttpStatus, string]> = {
      '23505': [HttpStatus.CONFLICT, 'El registro ya existe (clave duplicada)'],
      '23503': [HttpStatus.BAD_REQUEST, 'Referencia invalida: el registro relacionado no existe'],
      '23502': [HttpStatus.BAD_REQUEST, 'Faltan campos obligatorios'],
      '22P02': [HttpStatus.BAD_REQUEST, 'Formato de dato invalido'],
      '22003': [HttpStatus.BAD_REQUEST, 'Valor numerico fuera de rango'],
      '23P01': [HttpStatus.CONFLICT, 'Operacion bloqueada por una restriccion de integridad'],
      '40001': [HttpStatus.CONFLICT, 'Transaccion concurrente, reintente'],
      '57014': [HttpStatus.GATEWAY_TIMEOUT, 'Consulta cancelada por tiempo de espera agotado'],
    };
    if (e?.code && porCodigo[e.code]) {
      const [status, mensaje] = porCodigo[e.code];
      this.logger.warn(`${req.method} ${req.url} -> ${status} (${e.code})`);
      return responder(status, [mensaje]);
    }

    // multer
    const em = e?.message ?? '';
    if (em.includes('File too large')) {
      return responder(HttpStatus.PAYLOAD_TOO_LARGE, ['El archivo supera el limite de 15 MB']);
    }
    if (em.includes('LIMIT_') || em.includes('Unexpected field')) {
      return responder(HttpStatus.BAD_REQUEST, ['Archivo invalido o campo inesperado']);
    }

    this.logger.error(`${req.method} ${req.url} -> 500`, em);
    return responder(HttpStatus.INTERNAL_SERVER_ERROR, ['Error interno del servidor']);
  }
}