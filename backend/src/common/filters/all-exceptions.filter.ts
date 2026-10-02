import {
  ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Evita que los errores de Postgres (violaciones de FK, checks, duplicados) y los
 * errores de multer (archivo muy grande, MIME inesperado) se filtren al cliente
 * como 500 con el detalle de la consulta.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(excepcion: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    if (excepcion instanceof HttpException) {
      const status = excepcion.getStatus();
      const cuerpo = excepcion.getResponse();
      const mensaje =
        typeof cuerpo === 'string'
          ? cuerpo
          : ((cuerpo as { message?: string | string[] }).message ?? excepcion.message);
      return res.status(status).json({
        statusCode: status,
        mensaje: Array.isArray(mensaje) ? mensaje : [mensaje],
        ruta: req.url,
      });
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
      return res.status(status).json({ statusCode: status, mensaje: [mensaje], ruta: req.url });
    }

    // multer
    const em = e?.message ?? '';
    if (em.includes('File too large')) {
      return res.status(HttpStatus.PAYLOAD_TOO_LARGE).json({
        statusCode: HttpStatus.PAYLOAD_TOO_LARGE, mensaje: ['El archivo supera el limite de 15 MB'], ruta: req.url });
    }
    if (em.includes('LIMIT_') || em.includes('Unexpected field')) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST, mensaje: ['Archivo invalido o campo inesperado'], ruta: req.url });
    }

    this.logger.error(`${req.method} ${req.url} -> 500`, em);
    return res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      mensaje: ['Error interno del servidor'],
      ruta: req.url,
    });
  }
}