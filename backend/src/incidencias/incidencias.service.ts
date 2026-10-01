import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateIncidenciaDto } from './dto/create-incidencia.dto';
import { QueryIncidenciaDto } from './dto/query-incidencia.dto';

const SELECT_BASE = `
  SELECT i.id, i.codigo, t.nombre AS tipo, i.tipo_id AS "tipoId", i.descripcion, i.estado, i.prioridad,
         ST_Y(i.ubicacion::geometry) AS latitud, ST_X(i.ubicacion::geometry) AS longitud,
         i.referencia, i.unidad_asignada_id AS "unidadAsignadaId",
         i.ocurrido_en AS "ocurridoEn", i.atendido_en AS "atendidoEn",
         (SELECT count(*)::int FROM evidencias_multimedia e WHERE e.incidencia_id = i.id) AS evidencias
    FROM incidencias i JOIN tipos_incidencia t ON t.id = i.tipo_id`;

@Injectable()
export class IncidenciasService {
  constructor(private readonly ds: DataSource) {}

  async create(dto: CreateIncidenciaDto) {
    const rows = await this.ds.query(
      `INSERT INTO incidencias (tipo_id, descripcion, prioridad, ubicacion, referencia, ocurrido_en)
       VALUES ($1, $2,
               COALESCE($3::prioridad_nivel, (SELECT prioridad FROM tipos_incidencia WHERE id = $1)),
               ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, COALESCE($7::timestamptz, now()))
       RETURNING id`,
      [dto.tipoId, dto.descripcion ?? null, dto.prioridad ?? null, dto.longitud, dto.latitud,
       dto.referencia ?? null, dto.ocurridoEn ?? null],
    ).catch((e) => {
      if (e.code === '23503') throw new BadRequestException('tipoId no existe');
      throw e;
    });
    return this.findOne(rows[0].id);
  }

  async findAll(q: QueryIncidenciaDto) {
    const where: string[] = []; const params: any[] = [];
    if (q.estado) { params.push(q.estado); where.push(`i.estado = $${params.length}::estado_incidencia`); }
    if (q.tipoId) { params.push(q.tipoId); where.push(`i.tipo_id = $${params.length}`); }
    if (q.desde)  { params.push(q.desde);  where.push(`i.ocurrido_en >= $${params.length}`); }
    if (q.hasta)  { params.push(q.hasta);  where.push(`i.ocurrido_en <= $${params.length}`); }
    const w = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [{ total }] = await this.ds.query(`SELECT count(*)::int AS total FROM incidencias i ${w}`, params);
    params.push(q.limit, (q.page - 1) * q.limit);
    const data = await this.ds.query(
      `${SELECT_BASE} ${w} ORDER BY i.ocurrido_en DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
    return { data, meta: { total, page: q.page, limit: q.limit } };
  }

  async findOne(id: string) {
    const [inc] = await this.ds.query(`${SELECT_BASE} WHERE i.id = $1`, [id]);
    if (!inc) throw new NotFoundException('Incidencia no encontrada');
    inc.historial = await this.ds.query(
      `SELECT estado_anterior AS "estadoAnterior", estado_nuevo AS "estadoNuevo", registrado_en AS "registradoEn"
         FROM historial_incidencia WHERE incidencia_id = $1 ORDER BY registrado_en`, [id]);
    inc.evidenciasDetalle = await this.ds.query(
      `SELECT id, tipo, url_publica AS url, mime_type AS "mimeType", hash_sha256 AS hash, capturado_en AS "capturadoEn"
         FROM evidencias_multimedia WHERE incidencia_id = $1 ORDER BY capturado_en`, [id]);
    return inc;
  }

  async cambiarEstado(id: string, estado: string) {
    await this.findOne(id); // lanza 404 si no existe
    await this.ds.query(`UPDATE incidencias SET estado = $2::estado_incidencia WHERE id = $1`, [id, estado]);
    return this.findOne(id);
  }

  /** Despacha una unidad DISPONIBLE a la incidencia (transacción atómica). */
  async asignarUnidad(id: string, unidadId: string) {
    await this.ds.transaction(async (m) => {
      const [u] = await m.query(`SELECT estado FROM unidades_serenazgo WHERE id = $1 FOR UPDATE`, [unidadId]);
      if (!u) throw new NotFoundException('Unidad no encontrada');
      if (u.estado !== 'DISPONIBLE') throw new BadRequestException(`La unidad está ${u.estado}`);
      const [inc] = await m.query(`SELECT id FROM incidencias WHERE id = $1 FOR UPDATE`, [id]);
      if (!inc) throw new NotFoundException('Incidencia no encontrada');
      await m.query(`UPDATE unidades_serenazgo SET estado = 'OCUPADA' WHERE id = $1`, [unidadId]);
      await m.query(`UPDATE incidencias SET unidad_asignada_id = $2, estado = 'DESPACHADA' WHERE id = $1`, [id, unidadId]);
    });
    return this.findOne(id);
  }

  async geojson() {
    const rows = await this.ds.query(`SELECT feature FROM v_incidencias_geojson ORDER BY ocurrido_en DESC LIMIT 1000`);
    return { type: 'FeatureCollection', features: rows.map((r: any) => r.feature) };
  }
}
