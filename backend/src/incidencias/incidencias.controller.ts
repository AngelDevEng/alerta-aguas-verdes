import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { IncidenciasService } from './incidencias.service';
import { CreateIncidenciaDto } from './dto/create-incidencia.dto';
import { QueryIncidenciaDto } from './dto/query-incidencia.dto';
import { CambiarEstadoDto } from './dto/cambiar-estado.dto';
import { AsignarUnidadDto } from './dto/asignar-unidad.dto';

@ApiTags('incidencias')
@Controller('incidencias')
export class IncidenciasController {
  constructor(private readonly svc: IncidenciasService) {}

  @Post() create(@Body() dto: CreateIncidenciaDto) { return this.svc.create(dto); }
  @Get() findAll(@Query() q: QueryIncidenciaDto) { return this.svc.findAll(q); }
  @Get('geojson') geojson() { return this.svc.geojson(); }
  @Get(':id') findOne(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  @Patch(':id/estado')
  cambiarEstado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: CambiarEstadoDto) {
    return this.svc.cambiarEstado(id, dto.estado);
  }

  @Patch(':id/asignar')
  asignar(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AsignarUnidadDto) {
    return this.svc.asignarUnidad(id, dto.unidadId);
  }
}
