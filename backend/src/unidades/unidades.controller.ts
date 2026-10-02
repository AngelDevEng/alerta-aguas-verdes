import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UnidadesService } from './unidades.service';
import { CreateUnidadDto } from './dto/create-unidad.dto';
import { CercanasQueryDto, EstadoUnidadDto, RastroQueryDto, UbicacionDto } from './dto/ubicacion.dto';
import { AsignarResponsableDto } from './dto/asignar-responsable.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';

@ApiTags('unidades')
@ApiBearerAuth()
@Controller('unidades')
export class UnidadesController {
  constructor(private readonly svc: UnidadesService) {}

  @Roles('ADMIN', 'OPERADOR')
  @Patch(':id/responsable')
  responsable(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AsignarResponsableDto) {
    return this.svc.asignarResponsable(id, dto.usuarioId ?? null);
  }

  @Roles('ADMIN')
  @Post() create(@Body() dto: CreateUnidadDto) { return this.svc.create(dto); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get() findAll() { return this.svc.findAll(); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get('cercanas') cercanas(@Query() q: CercanasQueryDto) { return this.svc.cercanas(q.lon, q.lat, q.radio); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get(':id') findOne(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  // Un sereno solo puede reportar la posicion de la unidad que tiene asignada.
  @Roles('SERENO', 'OPERADOR', 'ADMIN')
  @Post(':id/ubicaciones')
  ubicacion(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UbicacionDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.registrarUbicacion(id, dto, u);
  }

  @Roles('ADMIN', 'OPERADOR')
  @Patch(':id/estado')
  estado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: EstadoUnidadDto) { return this.svc.cambiarEstado(id, dto.estado); }

  @Roles('ADMIN', 'OPERADOR', 'DIRECTIVO')
  @Get(':id/rastro')
  rastro(@Param('id', ParseUUIDPipe) id: string, @Query() q: RastroQueryDto) {
    return this.svc.rastro(id, q.limite);
  }
}