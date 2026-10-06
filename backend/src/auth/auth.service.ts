import {
  HttpException, HttpStatus, Injectable, Logger, UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { createHash, randomBytes } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { LoginDto, LoginPatrulleroDto } from './dto/login.dto';
import { JwtPayload, UsuarioAutenticado } from '../common/types';

const REFRESH_DIAS = 30;

// Hash bcrypt de una cadena aleatoria (no utilizable como contrasena). Se
// compara cuando la placa no existe o la unidad esta borrada: asi el tiempo de
// respuesta no delata si la placa esta dada de alta.
const HASH_DUMMY = '$2a$12$Z.ePFUvGF3GWytR.Nq5rqug93PWFWUi0SCZ0sc1wnGkdJcFnbChUu';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(private readonly ds: DataSource, private readonly jwt: JwtService) {}

  async login(dto: LoginDto) {
    const [u] = await this.ds.query(
      `SELECT u.id, u.dni, u.nombres, u.apellidos, u.email, u.password_hash, u.activo,
              r.nombre AS rol, r.id AS rol_id
         FROM usuarios u JOIN roles r ON r.id = u.rol_id
        WHERE u.dni = $1`,
      [dto.dni],
    );

    // Mismo mensaje para "no existe" y "mal password": no revela que DNIs estan dados de alta.
    if (!u) throw new UnauthorizedException('Credenciales invalidas');

    const coincide = bcrypt.compareSync(dto.password, u.password_hash);
    if (!coincide) {
      this.logger.warn(`Login fallido para dni=${dto.dni}`);
      throw new UnauthorizedException('Credenciales invalidas');
    }
    if (!u.activo) throw new UnauthorizedException('Usuario desactivado');

    // El hash del seed era un placeholder; sin esto nadie podria entrar nunca.
    if (!u.password_hash.startsWith('$2')) {
      throw new UnauthorizedException('Credencial del usuario sin configurar. Contacta al administrador.');
    }

    const usuario: UsuarioAutenticado = {
      id: u.id, dni: u.dni, nombres: u.nombres, apellidos: u.apellidos,
      email: u.email, rol: u.rol, rolId: u.rol_id,
    };
    return this.emitirTokens(usuario);
  }

  /**
   * Login de un sereno por placa de su unidad asignada.
   *
   * Recorre placa -> unidades_serenazgo.responsable_id -> usuarios (rol
   * SERENO) y valida el mismo password_hash que el login por DNI. No se toca
   * el esquema de usuarios.
   *
   * - Placa normalizada (mayusculas, sin espacios) antes de comparar.
   * - Mensaje generico y bcrypt dummy aunque la placa no exista: no revela en
   *   el texto ni en el tiempo si la unidad esta dada de alta.
   * - Limite de intentos por IP y por placa (ver dentroDeLimite).
   * - Las unidades con tipo PIE no tienen placa: su sereno entra por DNI con
   *   POST /auth/login, igual que hasta ahora.
   */
  async loginPatrullero(dto: LoginPatrulleroDto, ip: string) {
    const placa = dto.placa.trim().toUpperCase().replace(/\s+/g, '');

    // Rate limit antes de tocar la base, para que el brute-force no cueste
    // cada intento una consulta.
    if (!this.dentroDeLimite(this.intentosIp, ip, AuthService.LIMITE_IP)) {
      throw new HttpException('Demasiados intentos. Espera un momento.', HttpStatus.TOO_MANY_REQUESTS);
    }
    if (!this.dentroDeLimite(this.intentosPlaca, placa, AuthService.LIMITE_PLACA)) {
      throw new HttpException('Demasiados intentos. Espera un momento.', HttpStatus.TOO_MANY_REQUESTS);
    }

    const [u] = await this.ds.query(
      `SELECT u.id, u.dni, u.nombres, u.apellidos, u.email, u.password_hash, u.activo,
              r.nombre AS rol, r.id AS rol_id
         FROM unidades_serenazgo s
         JOIN usuarios u ON u.id = s.responsable_id
         JOIN roles r ON r.id = u.rol_id
        WHERE s.placa = $1
          AND r.nombre = 'SERENO'
          AND s.eliminado_en IS NULL`,
      [placa],
    );

    // Mismo camino de tiempo aunque la placa no tenga alta: compare contra un
    // hash bcrypt valido pero inutilizable.
    const coincide = bcrypt.compareSync(dto.password, u?.password_hash ?? HASH_DUMMY);
    if (!u || !coincide) throw new UnauthorizedException('Credenciales invalidas');
    if (!u.activo) throw new UnauthorizedException('Usuario desactivado');

    // Exito: se limpia el contador de esa placa para no castigar al operador
    // que fatiga al tipear.
    this.intentosPlaca.delete(placa);
    this.intentosIp.delete(ip);

    const usuario: UsuarioAutenticado = {
      id: u.id, dni: u.dni, nombres: u.nombres, apellidos: u.apellidos,
      email: u.email, rol: u.rol, rolId: u.rol_id,
    };
    return this.emitirTokens(usuario);
  }

  private readonly intentosIp = new Map<string, number[]>();
  private readonly intentosPlaca = new Map<string, number[]>();
  private static readonly VENTANA_MS = 15 * 60_000;
  private static readonly LIMITE_IP = 30;
  private static readonly LIMITE_PLACA = 8;

  /**
   * Limite en memoria de intentos por ventana deslizante. Para una sola
   * instancia de la API alcanza; si se escale a varias, esto tiene que pasar
   * por Redis (o se cuenta por separado en cada instancia).
   */
  private dentroDeLimite(mapa: Map<string, number[]>, clave: string, limite: number): boolean {
    const ahora = Date.now();
    const recientes = (mapa.get(clave) ?? []).filter((t) => ahora - t < AuthService.VENTANA_MS);
    if (recientes.length >= limite) {
      mapa.set(clave, recientes);
      return false;
    }
    recientes.push(ahora);
    mapa.set(clave, recientes);
    return true;
  }

  async refrescar(refreshToken: string) {
    const hash = this.hashToken(refreshToken);
    const [r] = await this.ds.query(
      `SELECT rt.id, rt.usuario_id FROM refresh_tokens rt
        WHERE rt.token_hash = $1 AND rt.revocado = FALSE AND rt.expira_en > now()`,
      [hash],
    );
    if (!r) throw new UnauthorizedException('Refresh token invalido, expirado o revocado');

    const [u] = await this.ds.query(
      `SELECT u.id, u.dni, u.nombres, u.apellidos, u.email, u.activo, r.nombre AS rol, r.id AS rol_id
         FROM usuarios u JOIN roles r ON r.id = u.rol_id
        WHERE u.id = $1`,
      [r.usuario_id],
    );
    if (!u) throw new UnauthorizedException('El usuario ya no existe');
    if (!u.activo) throw new UnauthorizedException('Usuario desactivado');

    await this.revocar(hash); // rotacion: el refresh es de un solo uso

    return this.emitirTokens({
      id: u.id, dni: u.dni, nombres: u.nombres, apellidos: u.apellidos,
      email: u.email, rol: u.rol, rolId: u.rol_id,
    });
  }

  async cerrarSesion(refreshToken: string) {
    await this.revocar(this.hashToken(refreshToken)).catch(() => undefined);
    return { ok: true };
  }

  private async emitirTokens(usuario: UsuarioAutenticado) {
    const payload: JwtPayload = {
      sub: usuario.id, rol: usuario.rol, email: usuario.email, dni: usuario.dni,
    };
    const accessToken = await this.jwt.signAsync(payload);

    const refreshToken = randomBytes(48).toString('base64url');
    const expiraEn = new Date(Date.now() + REFRESH_DIAS * 86400_000);
    await this.ds.query(
      `INSERT INTO refresh_tokens (usuario_id, token_hash, expira_en) VALUES ($1, $2, $3)`,
      [usuario.id, this.hashToken(refreshToken), expiraEn],
    );
    // Limpieza oportunista de tokens vencidos.
    await this.ds.query(`DELETE FROM refresh_tokens WHERE expira_en < now()`).catch(() => undefined);

    const nombreCompleto = `${usuario.nombres ?? ''} ${usuario.apellidos ?? ''}`.trim() || usuario.dni;

    return {
      success: true,
      // Alias para la app Kotlin legacy, que lee `token` y `nombre`.
      token: accessToken,
      nombre: nombreCompleto,
      id: usuario.id,
      rol: usuario.rol,
      email: usuario.email ?? null,
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.jwtTtlSegundos(),
      dni: usuario.dni,
      nombreCompleto,
      // Mismo usuario anidado: es lo que lee el cliente Flutter.
      usuario: {
        id: usuario.id,
        dni: usuario.dni,
        nombreCompleto,
        email: usuario.email ?? null,
        rol: usuario.rol,
      },
    };
  }

  private revocar(hash: string) {
    return this.ds.query(`UPDATE refresh_tokens SET revocado = TRUE WHERE token_hash = $1`, [hash]);
  }

  private hashToken(t: string): string {
    return createHash('sha256').update(t).digest('hex');
  }

  private jwtTtlSegundos(): number {
    const cfg = Number(process.env.JWT_EXPIRES_IN_SEG ?? 0);
    if (cfg > 0) return cfg;
    const ttl = process.env.JWT_EXPIRES_IN;
    if (ttl && /^\d+$/.test(ttl)) return Number(ttl);
    return 900;
  }
}