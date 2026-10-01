import { Controller, Get } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly ds: DataSource) {}

  @Get()
  async check() {
    const [{ postgis }] = await this.ds.query('SELECT PostGIS_Version() AS postgis');
    return { status: 'ok', postgis, timestamp: new Date().toISOString() };
  }
}
