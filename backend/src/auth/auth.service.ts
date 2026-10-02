import {
  Injectable, Logger, UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { createHash, randomBytes } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { LoginDto } from './dto/login.dto';
import { JwtPayload, UsuarioAutenticado } from '../common/types';

const REFRESH_DIAS = 30;

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

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.jwtTtlSegundos(),
      usuario: {
        id: usuario.id, dni: usuario.dni,
        nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`,
        email: usuario.email, rol: usuario.rol,
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