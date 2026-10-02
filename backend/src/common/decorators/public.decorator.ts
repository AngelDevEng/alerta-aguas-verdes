import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marca el endpoint como accesible sin token.
 * Solo debe usarse en login, refresh y salud. El JwtAuthGuard va registrado global,
 * asi que todo lo demas exige credenciales por defecto.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);