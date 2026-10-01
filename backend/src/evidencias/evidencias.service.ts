import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { createHash, randomUUID } from 'crypto';
import { DataSource } from 'typeorm';

const MIME_PERMITIDOS: Record<string, 'FOTO' | 'VIDEO' | 'AUDIO'> = {
  'image/jpeg': 'FOTO', 'image/png': 'FOTO', 'video/mp4': 'VIDEO', 'audio/mpeg': 'AUDIO', 'audio/mp4': 'AUDIO',
};

@Injectable()
export class EvidenciasService {
  private readonly supabase: SupabaseClient;
  private readonly bucket: string;

  constructor(private readonly ds: DataSource, cfg: ConfigService) {
    this.supabase = createClient(cfg.getOrThrow('SUPABASE_URL'), cfg.getOrThrow('SUPABASE_SERVICE_KEY'));
    this.bucket = cfg.get('SUPABASE_BUCKET') ?? 'evidencias';
  }

  async subir(incidenciaId: string, file: Express.Multer.File, lat?: number, lon?: number) {
    if (!file) throw new BadRequestException('Falta el archivo (campo "archivo")');
    const tipo = MIME_PERMITIDOS[file.mimetype];
    if (!tipo) throw new BadRequestException(`Tipo de archivo no permitido: ${file.mimetype}`);

    const [inc] = await this.ds.query(`SELECT id FROM incidencias WHERE id = $1`, [incidenciaId]);
    if (!inc) throw new NotFoundException('Incidencia no encontrada');

    const hash = createHash('sha256').update(file.buffer).digest('hex');
    const ext = file.originalname.split('.').pop()?.toLowerCase() ?? 'bin';
    const path = `${incidenciaId}/${randomUUID()}.${ext}`;

    const up = await this.supabase.storage.from(this.bucket).upload(path, file.buffer, { contentType: file.mimetype });
    if (up.error) throw new BadRequestException(`Error de almacenamiento: ${up.error.message}`);
    const url = this.supabase.storage.from(this.bucket).getPublicUrl(path).data.publicUrl;

    try {
      const hasGeo = Number.isFinite(lat) && Number.isFinite(lon);
      const [row] = await this.ds.query(
        `INSERT INTO evidencias_multimedia
           (incidencia_id, tipo, storage_path, url_publica, mime_type, tamano_bytes, hash_sha256, ubicacion)
         VALUES ($1, $2::tipo_evidencia, $3, $4, $5, $6, $7,
                 CASE WHEN $8::boolean THEN ST_SetSRID(ST_MakePoint($9, $10), 4326)::geography END)
         RETURNING id, tipo, url_publica AS url, hash_sha256 AS hash, capturado_en AS "capturadoEn"`,
        [incidenciaId, tipo, path, url, file.mimetype, file.size, hash, hasGeo, lon ?? 0, lat ?? 0]);
      return row;
    } catch (e: any) {
      await this.supabase.storage.from(this.bucket).remove([path]); // evita archivos huérfanos
      if (e.code === '23505') throw new ConflictException('Esta evidencia ya fue registrada (hash duplicado)');
      throw e;
    }
  }

  listar(incidenciaId: string) {
    return this.ds.query(
      `SELECT id, tipo, url_publica AS url, mime_type AS "mimeType", tamano_bytes AS "tamanoBytes",
              hash_sha256 AS hash, ST_Y(ubicacion::geometry) AS latitud, ST_X(ubicacion::geometry) AS longitud,
              capturado_en AS "capturadoEn"
         FROM evidencias_multimedia WHERE incidencia_id = $1 ORDER BY capturado_en`, [incidenciaId]);
  }
}
