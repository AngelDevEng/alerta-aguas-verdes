import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateUnidadDto } from './dto/create-unidad.dto';
import { UbicacionDto } from './dto/ubicacion.dto';
import { UsuarioAutenticado } from '../common/types';

const SELECT_BASE = `
  SELECT id, codigo, tipo, placa, estado, responsable_id AS "responsableId",
         ST_Y(ultima_ubicacion::geometry) AS latitud, ST_X(ultima_ubicacion::geometry) AS longitud,
         ultima_actualizacion AS "ultimaActualizacion"
    FROM unidades_serenazgo`;

@Injectable()
export class UnidadesService {
  constructor(private readonly ds: DataSource) {}

  async create(dto: CreateUnidadDto) {
    try {
      const [r] = await this.ds.query(
        `INSERT INTO unidades_serenazgo (codigo, tipo, placa) VALUES ($1, $2::tipo_unidad, $3) RETURNING id`,
        [dto.codigo, dto.tipo, dto.placa ?? null]);
      return this.findOne(r.id);
    } catch (e: any) {
      if (e.code === '23505') throw new ConflictException('Código o placa ya registrados');
      throw e;
    }
  }

  findAll() { return this.ds.query(`${SELECT_BASE} ORDER BY codigo`); }

  async findOne(id: string) {
    const [u] = await this.ds.query(`${SELECT_BASE} WHERE id = $1`, [id]);
    if (!u) throw new NotFoundException('Unidad no encontrada');
    return u;
  }

  cercanas(lon: number, lat: number, radio: number) {
    return this.ds.query(
      `SELECT id, codigo, tipo, round(distancia_m::numeric, 1)::float AS "distanciaM" FROM fn_unidades_cercanas($1, $2, $3)`,
      [lon, lat, Math.round(radio)]);
  }

  /**
   * Un SERENO solo puede reportar la posicion de la unidad que tiene asignada
   * (unidades_serenazgo.responsable_id). OPERADOR y ADMIN pueden reportar cualquiera.
   */
  async registrarUbicacion(id: string, dto: UbicacionDto, u: UsuarioAutenticado) {
    const unidad = await this.findOne(id);
    if (u.rol === 'SERENO' && unidad.responsableId !== u.id) {
      throw new ForbiddenException('No tienes asignada esta unidad');
    }
    await this.ds.query(
      `INSERT INTO ubicaciones_unidad (unidad_id, ubicacion, velocidad_kmh)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4)`,
      [id, dto.longitud, dto.latitud, dto.velocidadKmh ?? null]);
    return this.findOne(id);
  }

  /** Recorrido GPS reciente. Antes los puntos se escribian pero nunca se leian. */
  async rastro(id: string, limite = 200) {
    await this.findOne(id);
    return this.ds.query(
      `SELECT id, ST_Y(ubicacion::geometry) AS latitud, ST_X(ubicacion::geometry) AS longitud,
              velocidad_kmh AS "velocidadKmh", registrado_en AS "registradoEn"
         FROM ubicaciones_unidad
        WHERE unidad_id = $1
        ORDER BY registrado_en DESC
        LIMIT $2`,
      [id, limite]);
  }

  async asignarResponsable(id: string, usuarioId: string | null) {
    await this.findOne(id);
    await this.ds.query(`UPDATE unidades_serenazgo SET responsable_id = $2 WHERE id = $1`, [id, usuarioId]);
    return this.findOne(id);
  }

  async cambiarEstado(id: string, estado: string) {
    await this.findOne(id);
    await this.ds.query(`UPDATE unidades_serenazgo SET estado = $2::estado_unidad WHERE id = $1`, [id, estado]);
    return this.findOne(id);
  }
}
