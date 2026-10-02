import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { JwtPayload, UsuarioAutenticado } from '../types';

/**
 * Guard global: exige Bearer token salvo en rutas @Public().
 * Rehidrata el usuario desde la BD en cada peticion para que una baja o un cambio
 * de rol surta efecto de inmediato (el token por si solo duraria mas).
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly ds: DataSource,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const publico = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (publico) return true;

    const req = ctx.switchToHttp().getRequest();
    const token = this.extraerToken(req.headers?.authorization);
    if (!token) throw new UnauthorizedException('Falta el encabezado Authorization: Bearer <token>');

    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Token invalido o expirado');
    }

    const [u] = await this.ds.query(
      `SELECT u.id, u.dni, u.nombres, u.apellidos, u.email, u.activo, r.nombre AS rol, r.id AS rol_id
         FROM usuarios u JOIN roles r ON r.id = u.rol_id
        WHERE u.id = $1`,
      [payload.sub],
    );
    if (!u) throw new UnauthorizedException('El usuario del token ya no existe');
    if (!u.activo) throw new UnauthorizedException('Usuario desactivado');

    req.user = {
      id: u.id, dni: u.dni, nombres: u.nombres, apellidos: u.apellidos,
      email: u.email, rol: u.rol, rolId: u.rol_id,
    } as UsuarioAutenticado;
    return true;
  }

  private extraerToken(header?: string): string | null {
    if (!header) return null;
    const [esquema, valor] = header.split(' ');
    return esquema?.toLowerCase() === 'bearer' && valor ? valor : null;
  }
}