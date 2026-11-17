import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes, timingSafeEqual } from 'crypto';
import { DataSource } from 'typeorm';
import { RealtimeService } from '../realtime/realtime.service';
import { CreateAlertaDto } from './dto/create-alerta.dto';

const SELECT_BASE = `
  SELECT a.id, a.telefono, a.direccion, a.origen, a.estado, a.creada_en AS "creadaEn",
         a.aceptada_por AS "aceptadaPor", a.aceptada_en AS "aceptadaEn",
         a.unidad_id AS "unidadId", a.expira_en AS "expiraEn",
         a.atendida_en AS "atendidaEn", a.precision_m AS "precisionM",
         ST_Y(a.ubicacion::geometry) AS latitud, ST_X(a.ubicacion::geometry) AS longitud,
         a.incidencia_id AS "incidenciaId", i.codigo AS "incidenciaCodigo",
         i.unidad_asignada_id AS "unidadAsignadaId",
         a.reportante_id AS "reportanteId"
    FROM alertas a
    LEFT JOIN incidencias i ON i.id = a.incidencia_id`;

/** El token nunca se guarda en claro: solo su SHA-256 hex (CHAR(64)). */
function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class AlertasService {
  constructor(
    private readonly ds: DataSource,
    private readonly realtime: RealtimeService,
  ) {}

  /**
   * El SOS abre ademas una incidencia de tipo EMER con prioridad CRITICA, para que
   * entre al flujo normal de despacho. El legado solo insertaba en `alertas` y se
   * quedaba ahi: la alerta nunca llegaba a la sala de operacion.
   *
   * Una sola SOS viva por dispositivo: si ya hay una ACTIVA/ACEPTADA con ese
   * dispositivo_id se devuelve esa (con un token de sesion nuevo), no se crea
   * otra. El token se guarda hasheado y se devuelve una sola vez en el cuerpo.
   */
  async crear(dto: CreateAlertaDto, reportanteId?: string, dispositivoId?: string, ip?: string) {
    const dispositivo = dispositivoId?.trim() || null;

    if (dispositivo) {
      const existente = await this.alertaVivaPorDispositivo(dispositivo);
      if (existente) {
        const sessionToken = await this.nuevaSesion(existente.id as string, dispositivo, ip);
        return { ...(await this.findOne(existente.id as string)), sessionToken };
      }
    }

    const token = randomBytes(32).toString('base64url');

    try {
      const alertaId = await this.insertarAlerta(dto, reportanteId, dispositivo, hashToken(token), ip);
      const alerta = await this.findOne(alertaId);
      this.realtime.notificarNuevaAlerta(alerta);
      return { ...alerta, sessionToken: token };
    } catch (e: any) {
      // Carrera con otra peticion del mismo dispositivo: el indice unico rechazo
      // la segunda alta. Se devuelve la que gano, con un token nuevo.
      if (e?.code === '23505' && dispositivo) {
        const existente = await this.alertaVivaPorDispositivo(dispositivo);
        if (existente) {
          const sessionToken = await this.nuevaSesion(existente.id as string, dispositivo, ip);
          return { ...(await this.findOne(existente.id as string)), sessionToken };
        }
      }
      throw e;
    }
  }

  private async alertaVivaPorDispositivo(dispositivo: string) {
    const [row] = await this.ds.query(
      `SELECT id FROM alertas
        WHERE dispositivo_id = $1 AND estado IN ('ACTIVA','ACEPTADA')
        ORDER BY creada_en DESC
        LIMIT 1`,
      [dispositivo],
    );
    return row ?? null;
  }

  private async insertarAlerta(
    dto: CreateAlertaDto,
    reportanteId: string | undefined,
    dispositivo: string | null,
    tokenHash: string,
    ip: string | undefined,
  ) {
    return this.ds.transaction(async (m) => {
      const [inc] = await m.query(
        `INSERT INTO incidencias (tipo_id, descripcion, prioridad, ubicacion, referencia, reportado_por)
         VALUES ((SELECT id FROM tipos_incidencia WHERE codigo = 'EMER'),
                 $1, 'CRITICA',
                 ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4, $5)
         RETURNING id`,
        [`Alerta SOS ${dto.origen ?? 'APP'}`, dto.longitud, dto.latitud,
         dto.direccion ?? null, reportanteId ?? null]);

      const [a] = await m.query(
        `INSERT INTO alertas
           (incidencia_id, reportante_id, telefono, ubicacion, direccion, precision_m, origen, dispositivo_id, expira_en)
         VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7, COALESCE($8, 'APP'), $9,
                 now() + interval '20 minutes')
         RETURNING id`,
        [inc.id, reportanteId ?? null, dto.telefono ?? null, dto.longitud, dto.latitud,
         dto.direccion ?? null, dto.precisionM ?? null, dto.origen ?? null, dispositivo]);

      await m.query(
        `INSERT INTO sessions_anonimas (alerta_id, token_hash, dispositivo_id, ip, expira_en)
         VALUES ($1, $2, $3, $4, now() + interval '24 hours')`,
        [a.id, tokenHash, dispositivo, ip ?? null]);

      return a.id as string;
    });
  }

  listar(estado?: string, limite = 100) {
    const where = estado ? `WHERE a.estado = $2::varchar` : '';
    return this.ds.query(`${SELECT_BASE} ${where} ORDER BY a.creada_en DESC LIMIT $1`, [limite, ...(estado ? [estado] : [])]);
  }

  activas() {
    return this.ds.query(
      `SELECT id, telefono, direccion, estado, origen, creada_en AS "creadaEn",
              latitud, longitud, incidencia_id AS "incidenciaId", incidencia_codigo AS "incidenciaCodigo"
         FROM v_alertas_activas ORDER BY creada_en ASC`);
  }

  async findOne(id: string) {
    const [a] = await this.ds.query(`${SELECT_BASE} WHERE a.id = $1`, [id]);
    if (!a) throw new NotFoundException('Alerta no encontrada');
    return a;
  }

  /**
   * Seguimiento del ciudadano: estado de su alerta, sus propias ubicaciones y
   * la ultima posicion de la unidad si ya acepto. No usa el JWT del ciudadano
   * (no tiene cuenta): valida el token anonimo hasheado en sessions_anonimas.
   */
  async seguimiento(id: string, token?: string) {
    if (!token) throw new UnauthorizedException('Falta X-Session-Token');

    const [sesion] = await this.ds.query(
      `SELECT id, token_hash FROM sessions_anonimas
        WHERE alerta_id = $1 AND revocado = FALSE AND expira_en > now()
        ORDER BY expira_en DESC LIMIT 1`,
      [id],
    );

    const hash = hashToken(token);
    const coincide =
      sesion?.token_hash &&
      hash.length === sesion.token_hash.length &&
      timingSafeEqual(
        Buffer.from(hash, 'hex'),
        Buffer.from(sesion.token_hash as string, 'hex'),
      );

    if (!coincide) {
      throw new UnauthorizedException('Sesion de seguimiento invalida o expirada');
    }

    const alerta = await this.findOne(id);

    const ubicaciones = await this.ds.query(
      `SELECT ST_Y(ubicacion::geometry) AS latitud, ST_X(ubicacion::geometry) AS longitud,
              velocidad_kmh AS "velocidadKmh", registrado_en AS "registradoEn"
         FROM ubicaciones_ciudadano
        WHERE alerta_id = $1
        ORDER BY registrado_en DESC
        LIMIT 50`,
      [id],
    );

    let sereno: any = null;
    if (alerta.unidadId) {
      const rows = await this.ds.query(
        `SELECT id, codigo,
                ST_Y(ultima_ubicacion::geometry) AS latitud,
                ST_X(ultima_ubicacion::geometry) AS longitud,
                ultima_actualizacion AS "ultimaActualizacion"
           FROM unidades_serenazgo
          WHERE id = $1 AND eliminado_en IS NULL`,
        [alerta.unidadId],
      );
      sereno = rows[0] ?? null;
    }

    return { alerta, ciudadano: { ubicaciones }, sereno: sereno ?? null };
  }

  /** Crea una sesion anonima nueva para una alerta existente. */
  private async nuevaSesion(alertaId: string, dispositivoId: string | null, ip?: string) {
    const token = randomBytes(32).toString('base64url');
    await this.ds.query(
      `INSERT INTO sessions_anonimas (alerta_id, token_hash, dispositivo_id, ip, expira_en)
       VALUES ($1, $2, $3, $4, now() + interval '24 hours')`,
      [alertaId, hashToken(token), dispositivoId, ip ?? null],
    );
    return token;
  }

  /** Al cerrar la alerta se cierra tambien la incidencia CRITICA asociada y se libera la unidad. */
  async cambiarEstado(id: string, estado: string, usuarioId: string) {
    await this.findOne(id);

    await this.ds.transaction(async (m) => {
      await m.query(
        `UPDATE alertas SET estado = $2::varchar,
                atendida_por  = CASE WHEN $2::varchar IN ('ATENDIDA','CANCELADA','FALSA') THEN $3::uuid ELSE atendida_por END,
                atendida_en   = CASE WHEN $2::varchar IN ('ATENDIDA','CANCELADA','FALSA') THEN now() ELSE atendida_en END
          WHERE id = $1`,
        [id, estado, usuarioId]);

      // Al cerrar la alerta se acorta la ventana del token. El token NO se
      // revoca: queda vigente 10 minutos solo para GET /seguimiento. Las peticiones
      // POST /posicion y POST /cancelar rechazan alertas terminales antes de validar el token.
      if (['ATENDIDA', 'CANCELADA', 'FALSA'].includes(estado)) {
        await m.query(
          `UPDATE sessions_anonimas
              SET expira_en = LEAST(expira_en, now() + interval '10 minutes')
            WHERE alerta_id = $1`,
          [id],
        );
      }

      const [a] = await m.query(`SELECT incidencia_id FROM alertas WHERE id = $1`, [id]);
      if (!a?.incidencia_id) return;

      // ATENDIDA mantiene la incidencia como ATENDIDA; CANCELADA y FALSA la cierran como CANCELADA.
      const nuevoEstado = estado === 'ATENDIDA' ? 'ATENDIDA' : 'CANCELADA';
      await m.query(
        `UPDATE incidencias SET estado = $2::estado_incidencia WHERE id = $1 AND estado NOT IN ('ATENDIDA','CANCELADA')`,
        [a.incidencia_id, nuevoEstado]);

      const [inc] = await m.query(`SELECT unidad_asignada_id FROM incidencias WHERE id = $1`, [a.incidencia_id]);
      if (inc?.unidad_asignada_id) {
        await m.query(
          `UPDATE unidades_serenazgo SET estado = 'DISPONIBLE' WHERE id = $1 AND estado = 'OCUPADA'`,
          [inc.unidad_asignada_id]);
      }
    });
    return this.findOne(id);
  }
}