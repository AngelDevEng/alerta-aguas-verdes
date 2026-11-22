import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes, timingSafeEqual } from 'crypto';
import { DataSource } from 'typeorm';
import { RealtimeService } from '../realtime/realtime.service';
import { CreateAlertaDto } from './dto/create-alerta.dto';

const SELECT_BASE = `
  SELECT a.id, a.telefono, a.direccion, a.origen, a.estado, a.creada_en AS "creadaEn",
         a.aceptada_por AS "aceptadaPor", a.aceptada_en AS "aceptadaEn",
         a.unidad_id AS "unidadId", a.expira_en AS "expiraEn",
         a.atendida_en AS "atendidaEn", a.precision_m AS "precisionM",
         a.sin_ubicacion AS "sinUbicacion",
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

/** SHA-256 hex de la `Idempotency-Key` del cliente. Nunca se guarda en claro. */
function hashClave(clave: string): string {
  return createHash('sha256').update(clave).digest('hex');
}

/**
 * SHA-256 del cuerpo canonico del SOS. Permite detectar una misma clave
 * reutilizada con datos distintos (no deberia pasar: la clave es un UUID
 * aleatorio por envio).
 */
function hashSolicitud(dto: CreateAlertaDto): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        latitud: dto.latitud,
        longitud: dto.longitud,
        telefono: dto.telefono ?? null,
        direccion: dto.direccion ?? null,
        precisionM: dto.precisionM ?? null,
        origen: dto.origen ?? 'APP',
        sinUbicacion: dto.sinUbicacion ?? false,
      }),
    )
    .digest('hex');
}

/** Estados a partir de los cuales la alerta ya no admite seguimiento. */
const ESTADOS_TERMINALES = ['ATENDIDA', 'CANCELADA', 'FALSA', 'EXPIRADA'];

@Injectable()
export class AlertasService {
  private readonly logger = new Logger(AlertasService.name);

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
   * otra.
   *
   * Idempotencia: si llega `idempotencyKey` y ya existe una fila para esa clave
   * con el MISMO dispositivo, se devuelve la alerta original sin crear otra.
   * Asi un reintento (mala señal, timeout, reanudar la app) no duplica la SOS.
   */
  async crear(
    dto: CreateAlertaDto,
    reportanteId?: string,
    dispositivoId?: string,
    ip?: string,
    idempotencyKey?: string,
  ) {
    const dispositivo = dispositivoId?.trim() || null;
    const clave = idempotencyKey?.trim() || null;
    const claveHash = clave ? hashClave(clave) : null;
    const solicitudHash = hashSolicitud(dto);

    // Limpieza best-effort de claves vencidas. No se bloquea el envio por esto.
    void this.limpiarIdempotenciaExpirada();

    // 1. Reintento idempotente: misma clave + mismo dispositivo -> alerta original.
    if (claveHash) {
      const previa = await this.idempotenciaPorClave(claveHash);
      if (previa) {
        this.validarReintento(previa, dispositivo, solicitudHash);
        return this.entregarAlerta(previa.alerta_id as string, dispositivo, ip);
      }
    }

    if (dispositivo) {
      const existente = await this.alertaVivaPorDispositivo(dispositivo);
      if (existente) {
        // La SOS viva se reutiliza; si vino clave, se vincula a ella para que un
        // reintento posterior con la misma clave tambien la encuentre.
        if (claveHash) {
          await this.vincularIdempotencia(claveHash, solicitudHash, existente.id, dispositivo);
        }
        const sessionToken = await this.nuevaSesion(existente.id as string, dispositivo, ip);
        return { ...(await this.findOne(existente.id as string)), sessionToken };
      }
    }

    const token = randomBytes(32).toString('base64url');

    try {
      const alertaId = await this.insertarAlerta(
        dto,
        reportanteId,
        dispositivo,
        hashToken(token),
        ip,
        claveHash,
        solicitudHash,
      );
      const alerta = await this.findOne(alertaId);
      this.realtime.notificarNuevaAlerta(alerta);
      return { ...alerta, sessionToken: token };
    } catch (e: any) {
      // Carrera con otra peticion: el indice unico rechazo la segunda alta.
      // Se devuelve la que gano.
      if (e?.code === '23505' && claveHash) {
        const previa = await this.idempotenciaPorClave(claveHash);
        if (previa) {
          this.validarReintento(previa, dispositivo, solicitudHash);
          return this.entregarAlerta(previa.alerta_id as string, dispositivo, ip);
        }
      }
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

  /**
   * Una `Idempotency-Key` identifica un unico envio. Si se reutiliza con otro
   * dispositivo o con otro cuerpo, no es un reintento: es una colision (UUID
   * repetido o bug del cliente). Se responde 409 en vez de devolver una alerta
   * que no corresponde a quien pregunta.
   */
  private validarReintento(
    previa: { dispositivo_id: string | null; solicitud_hash: string },
    dispositivo: string | null,
    solicitudHash: string,
  ) {
    if (previa.dispositivo_id !== dispositivo) {
      throw new ConflictException('La clave de idempotencia ya fue usada por otro dispositivo.');
    }
    if (previa.solicitud_hash !== solicitudHash) {
      throw new ConflictException('La clave de idempotencia ya fue usada con otra solicitud.');
    }
  }

  /**
   * Respuesta de una alerta ya existente (reintento idempotente o SOS viva).
   * Si la alerta ya cerro, se devuelve sin token: no tiene sentido abrir una
   * sesion de seguimiento para una alerta terminal.
   */
  private async entregarAlerta(alertaId: string, dispositivo: string | null, ip?: string) {
    const alerta = await this.findOne(alertaId);
    if (ESTADOS_TERMINALES.includes(alerta.estado)) return alerta;
    const sessionToken = await this.nuevaSesion(alertaId, dispositivo, ip);
    return { ...alerta, sessionToken };
  }

  /**
   * Reintento idempotente: misma clave + mismo dispositivo -> alerta original.
   *
   * Si la tabla no existe (SQLSTATE 42P01) se registra una advertencia y se
   * degrada a "sin idempotencia". Cualquier otro error se registra con detalle
   * y tambien se degrada: el SOS nunca debe fallar por esta capa.
   */
  private async idempotenciaPorClave(claveHash: string) {
    try {
      const [row] = await this.ds.query(
        `SELECT alerta_id, dispositivo_id, solicitud_hash
           FROM alertas_idempotencia
          WHERE clave_hash = $1
          LIMIT 1`,
        [claveHash],
      );
      return row ?? null;
    } catch (e: any) {
      if (e?.code === '42P01') {
        this.logger.warn(
          'Tabla alertas_idempotencia no existe (SQLSTATE 42P01). Se degrada a sin idempotencia; aplica la migracion 09.',
        );
      } else {
        this.logger.error(
          `Fallo al consultar alertas_idempotencia; se degrada a sin idempotencia: ${e?.message ?? e}`,
          e?.stack,
        );
      }
      return null;
    }
  }

  private async vincularIdempotencia(
    claveHash: string,
    solicitudHash: string,
    alertaId: string,
    dispositivo: string | null,
  ) {
    try {
      await this.ds.query(
        `INSERT INTO alertas_idempotencia (clave_hash, solicitud_hash, alerta_id, dispositivo_id)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (clave_hash) DO NOTHING`,
        [claveHash, solicitudHash, alertaId, dispositivo],
      );
    } catch (e: any) {
      if (e?.code === '42P01') {
        this.logger.warn(
          'Tabla alertas_idempotencia no existe (SQLSTATE 42P01). No se vincula la clave; aplica la migracion 09.',
        );
      } else {
        this.logger.error(
          `Fallo al vincular idempotencia; el SOS se crea igual: ${e?.message ?? e}`,
          e?.stack,
        );
      }
    }
  }

  private async limpiarIdempotenciaExpirada() {
    try {
      await this.ds.query(`DELETE FROM alertas_idempotencia WHERE expira_en < now()`);
    } catch (e: any) {
      if (e?.code === '42P01') {
        this.logger.warn(
          'Tabla alertas_idempotencia no existe (SQLSTATE 42P01). No se limpia; aplica la migracion 09.',
        );
      } else {
        this.logger.error(
          `Fallo al limpiar idempotencia expirada: ${e?.message ?? e}`,
          e?.stack,
        );
      }
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
    claveHash?: string | null,
    solicitudHash?: string,
  ) {
    // Sin ubicacion: la alerta se crea igual. Se conservan las coordenadas que
    // lleguen (p. ej. la ultima conocida) pero se marca la direccion y se
    // omite la precision para no dar una precision enganosa. Si no llegaron
    // coordenadas (sinUbicacion), se insertan 0,0: la columna `ubicacion` es
    // NOT NULL y la marca `sin_ubicacion` es la que indica que no son fiables.
    const sinUbicacion = dto.sinUbicacion === true;
    const direccion = sinUbicacion ? 'Sin ubicación' : dto.direccion ?? null;
    const precisionM = sinUbicacion ? null : dto.precisionM ?? null;
    const latitud = dto.latitud ?? 0;
    const longitud = dto.longitud ?? 0;

    return this.ds.transaction(async (m) => {
      const [inc] = await m.query(
        `INSERT INTO incidencias (tipo_id, descripcion, prioridad, ubicacion, referencia, reportado_por)
         VALUES ((SELECT id FROM tipos_incidencia WHERE codigo = 'EMER'),
                 $1, 'CRITICA',
                 ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4, $5)
         RETURNING id`,
        [`Alerta SOS ${dto.origen ?? 'APP'}`, longitud, latitud,
         direccion, reportanteId ?? null]);

      const [a] = await m.query(
        `INSERT INTO alertas
           (incidencia_id, reportante_id, telefono, ubicacion, direccion, precision_m, origen, dispositivo_id, expira_en, sin_ubicacion)
         VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7, COALESCE($8, 'APP'), $9,
                 now() + interval '20 minutes', $10)
         RETURNING id`,
        [inc.id, reportanteId ?? null, dto.telefono ?? null, longitud, latitud,
         direccion, precisionM, dto.origen ?? null, dispositivo, sinUbicacion]);

      await m.query(
        `INSERT INTO sessions_anonimas (alerta_id, token_hash, dispositivo_id, ip, expira_en)
         VALUES ($1, $2, $3, $4, now() + interval '24 hours')`,
        [a.id, tokenHash, dispositivo, ip ?? null]);

      if (claveHash) {
        // SAVEPOINT: la deduplicacion es best-effort y NO debe tumbar la
        // transaccion. Sin el savepoint, un fallo del insert (tabla ausente,
        // restriccion, etc.) abortaria toda la transaccion y se perderian la
        // incidencia y la alerta recien creadas. Con el savepoint se revierte
        // solo este paso y la alerta se confirma igual.
        const savepoint = 'sp_alertas_idempotencia';
        await m.query(`SAVEPOINT ${savepoint}`);
        try {
          await m.query(
            `INSERT INTO alertas_idempotencia (clave_hash, solicitud_hash, alerta_id, dispositivo_id)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (clave_hash) DO NOTHING`,
            [claveHash, solicitudHash ?? '', a.id, dispositivo],
          );
          await m.query(`RELEASE SAVEPOINT ${savepoint}`);
        } catch (e: any) {
          try {
            await m.query(`ROLLBACK TO SAVEPOINT ${savepoint}`);
          } catch {
            // Si el rollback tambien falla, la transaccion ya estaba abortada;
            // se registra abajo y el SOS no se pierde por esta capa.
          }
          if (e?.code === '42P01') {
            this.logger.warn(
              'Tabla alertas_idempotencia no existe (SQLSTATE 42P01). La alerta se creo sin deduplicar por clave; aplica la migracion 09.',
            );
          } else {
            this.logger.error(
              `Fallo al registrar la clave de idempotencia; la alerta se creo igual: ${e?.message ?? e}`,
              e?.stack,
            );
          }
        }
      }

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
    const alerta = await this.findOne(id);

    // ACEPTADA: el sereno toma la alerta con su propia unidad. El cliente nunca
    // envia unidadId (objetivo general.md:167): se resuelve por
    // unidades_serenazgo.responsable_id. La restriccion chk_alerta_aceptada exige
    // aceptada_por, aceptada_en y unidad_id, asi que los tres se escriben juntos.
    let unidadAceptada: string | null = null;
    if (estado === 'ACEPTADA') {
      if (alerta.estado !== 'ACTIVA') {
        throw new ConflictException('La alerta ya no esta activa.');
      }

      const unidades = await this.ds.query(
        `SELECT id, estado FROM unidades_serenazgo
          WHERE responsable_id = $1 AND eliminado_en IS NULL
          ORDER BY creado_en`,
        [usuarioId],
      );
      if (unidades.length === 0) {
        throw new BadRequestException('El sereno no tiene una unidad asignada.');
      }
      if (unidades.length > 1) {
        throw new ConflictException(
          'El sereno tiene varias unidades asignadas. Pida ayuda al operador.',
        );
      }

      const unidad = unidades[0];
      if (unidad.estado !== 'DISPONIBLE') {
        throw new ConflictException('La unidad asignada no esta disponible.');
      }
      unidadAceptada = unidad.id as string;
    }

    const terminal = ['ATENDIDA', 'CANCELADA', 'FALSA', 'EXPIRADA'];

    await this.ds.transaction(async (m) => {
      if (estado === 'ACEPTADA') {
        await m.query(
          `UPDATE alertas
              SET estado = 'ACEPTADA',
                  aceptada_por = $2::uuid,
                  aceptada_en  = now(),
                  unidad_id    = $3::uuid
            WHERE id = $1`,
          [id, usuarioId, unidadAceptada],
        );

        await m.query(
          `UPDATE unidades_serenazgo SET estado = 'OCUPADA' WHERE id = $1`,
          [unidadAceptada],
        );

        // La incidencia CRITICA que abrio el SOS pasa a EN_ATENCION con la unidad
        // del sereno; el trigger fn_historial_estado registra el movimiento.
        const [a] = await m.query(`SELECT incidencia_id FROM alertas WHERE id = $1`, [id]);
        if (a?.incidencia_id) {
          await m.query(
            `UPDATE incidencias
                SET estado = 'EN_ATENCION'::estado_incidencia,
                    unidad_asignada_id = $2::uuid
              WHERE id = $1 AND estado NOT IN ('ATENDIDA','CANCELADA')`,
            [a.incidencia_id, unidadAceptada],
          );
        }
        return;
      }

      await m.query(
        `UPDATE alertas SET estado = $2::varchar,
                atendida_por  = CASE WHEN $2::varchar IN ('ATENDIDA','CANCELADA','FALSA') THEN $3::uuid ELSE atendida_por END,
                atendida_en   = CASE WHEN $2::varchar IN ('ATENDIDA','CANCELADA','FALSA') THEN now() ELSE atendida_en END
          WHERE id = $1`,
        [id, estado, usuarioId]);

      // Al cerrar la alerta se acorta la ventana del token. El token NO se
      // revoca: queda vigente 10 minutos solo para GET /seguimiento. Las peticiones
      // POST /posicion y POST /cancelar rechazan alertas terminales antes de validar el token.
      if (terminal.includes(estado)) {
        await m.query(
          `UPDATE sessions_anonimas
              SET expira_en = LEAST(expira_en, now() + interval '10 minutes')
            WHERE alerta_id = $1`,
          [id],
        );
      }

      const [a] = await m.query(`SELECT incidencia_id FROM alertas WHERE id = $1`, [id]);
      if (!a?.incidencia_id) return;

      // ATENDIDA mantiene la incidencia como ATENDIDA; el resto la cierra como CANCELADA.
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