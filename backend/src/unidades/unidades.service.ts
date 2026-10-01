import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateUnidadDto } from './dto/create-unidad.dto';
import { UbicacionDto } from './dto/ubicacion.dto';

const SELECT_BASE = `
  SELECT id, codigo, tipo, placa, estado,
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

  async registrarUbicacion(id: string, dto: UbicacionDto) {
    await this.findOne(id);
    await this.ds.query(
      `INSERT INTO ubicaciones_unidad (unidad_id, ubicacion, velocidad_kmh)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, $4)`,
      [id, dto.longitud, dto.latitud, dto.velocidadKmh ?? null]);
    return this.findOne(id);
  }

  async cambiarEstado(id: string, estado: string) {
    await this.findOne(id);
    await this.ds.query(`UPDATE unidades_serenazgo SET estado = $2::estado_unidad WHERE id = $1`, [id, estado]);
    return this.findOne(id);
  }
}
