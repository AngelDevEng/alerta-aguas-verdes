export type RolNombre = 'ADMIN' | 'OPERADOR' | 'SERENO' | 'DIRECTIVO' | 'CIUDADANO';

export interface UsuarioAutenticado {
  id: string;
  dni: string;
  nombres: string;
  apellidos: string;
  email: string;
  rol: RolNombre;
  rolId: number;
}

export interface JwtPayload {
  sub: string;
  rol: RolNombre;
  email: string;
  dni: string;
  iat?: number;
  exp?: number;
}