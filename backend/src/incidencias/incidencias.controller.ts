import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IncidenciasService } from './incidencias.service';
import { CreateIncidenciaDto } from './dto/create-incidencia.dto';
import { QueryIncidenciaDto } from './dto/query-incidencia.dto';
import { CambiarEstadoDto } from './dto/cambiar-estado.dto';
import { AsignarUnidadDto } from './dto/asignar-unidad.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';

@ApiTags('incidencias')
@ApiBearerAuth()
@Controller('incidencias')
export class IncidenciasController {
  constructor(private readonly svc: IncidenciasService) {}

  // Un ciudadano puede reportar; un sereno tambien. El USER id queda registrado como reportado_por.
  @Roles('CIUDADANO', 'SERENO', 'OPERADOR', 'ADMIN')
  @Post() create(@Body() dto: CreateIncidenciaDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.create(dto, u.id);
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get() findAll(@Query() q: QueryIncidenciaDto) { return this.svc.findAll(q); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get('geojson') geojson() { return this.svc.geojson(); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get(':id') findOne(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN')
  @Patch(':id/estado')
  cambiarEstado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: CambiarEstadoDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.cambiarEstado(id, dto.estado, u.id);
  }

  @Roles('OPERADOR', 'ADMIN')
  @Patch(':id/asignar')
  asignar(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AsignarUnidadDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.asignarUnidad(id, dto.unidadId, u.id);
  }
}