import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { RolNombre } from '../types';

/** Guard global: valida @Roles(...) contra el rol resuelto por JwtAuthGuard. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const requeridos = this.reflector.getAllAndOverride<RolNombre[]>(ROLES_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (!requeridos || requeridos.length === 0) return true;

    const req = ctx.switchToHttp().getRequest();
    const rol: RolNombre | undefined = req.user?.rol;
    if (!rol) throw new ForbiddenException('No se pudo determinar el rol del usuario');
    if (!requeridos.includes(rol)) {
      throw new ForbiddenException(`Requiere uno de estos roles: ${requeridos.join(', ')}`);
    }
    return true;
  }
}