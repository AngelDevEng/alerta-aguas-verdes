import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { UsuarioAutenticado } from '../types';

/** Inyecta el usuario resuelto por JwtAuthGuard. */
export const CurrentUser = createParamDecorator(
  (_datos: unknown, ctx: ExecutionContext): UsuarioAutenticado => {
    const req = ctx.switchToHttp().getRequest();
    return req.user;
  },
);