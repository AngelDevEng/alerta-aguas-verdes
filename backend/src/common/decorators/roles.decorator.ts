import { SetMetadata } from '@nestjs/common';
import { RolNombre } from '../types';

export const ROLES_KEY = 'roles';

/** Restringe el endpoint a los roles indicados. Implica que el usuario esté autenticado. */
export const Roles = (...roles: RolNombre[]) => SetMetadata(ROLES_KEY, roles);