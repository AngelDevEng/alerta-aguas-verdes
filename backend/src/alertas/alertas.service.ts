import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateAlertaDto } from './dto/create-alerta.dto';

const SELECT_BASE = `
  SELECT a.id, a.telefono, a.direccion, a.origen, a.estado, a.creada_en AS "creadaEn",
         a.atendida_en AS "atendidaEn", a.precision_m AS "precisionM",
         ST_Y(a.ubicacion::geometry) AS latitud, ST_X(a.ubicacion::geometry) AS longitud,
         a.incidencia_id AS "incidenciaId", i.codigo AS "incidenciaCodigo",
         a.reportante_id AS "reportanteId"
    FROM alertas a
    LEFT JOIN incidencias i ON i.id = a.incidencia_id`;

@Injectable()
export class AlertasService {
  constructor(private readonly ds: DataSource) {}

  /**
   * El SOS abre ademas una incidencia de tipo EMER con prioridad CRITICA, para que
   * entre al flujo normal de despacho. El legado solo insertaba en `alertas` y se
   * quedaba ahi: la alerta nunca llegaba a la sala de operacion.
   */
  async crear(dto: CreateAlertaDto, reportanteId?: string) {
    const { alertaId } = await this.ds.transaction(async (m) => {
      const [inc] = await m.query(
        `INSERT INTO incidencias (tipo_id, descripcion, prioridad, ubicacion, referencia, reportado_por)
         VALUES ((SELECT id FROM tipos_incidencia WHERE codigo = 'EMER'),
                 $1, 'CRITICA',
                 ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4, $5)
         RETURNING id`,
        [`Alerta SOS ${dto.origen ?? 'APP'}`, dto.longitud, dto.latitud,
         dto.direccion ?? null, reportanteId ?? null]);

      const [a] = await m.query(
        `INSERT INTO alertas (incidencia_id, reportante_id, telefono, ubicacion, direccion, precision_m, origen)
         VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7, COALESCE($8, 'APP'))
         RETURNING id`,
        [inc.id, reportanteId ?? null, dto.telefono ?? null, dto.longitud, dto.latitud,
         dto.direccion ?? null, dto.precisionM ?? null, dto.origen ?? null]);
      return { alertaId: a.id as string };
    });
    return this.findOne(alertaId);
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