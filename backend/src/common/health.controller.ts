import { Controller, Get } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ApiTags } from '@nestjs/swagger';
import { Public } from './decorators/public.decorator';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly ds: DataSource) {}

  /** Publico: Render lo usa como healthCheckPath y no envia credenciales. */
  @Public()
  @Get()
  async check() {
    const [{ postgis }] = await this.ds.query('SELECT PostGIS_Version() AS postgis');
    return { status: 'ok', postgis, timestamp: new Date().toISOString() };
  }
}
