import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiTags } from '@nestjs/swagger';
import { UnidadesService } from './unidades.service';
import { CreateUnidadDto } from './dto/create-unidad.dto';
import { CercanasQueryDto, EstadoUnidadDto, RastroQueryDto, UbicacionDto } from './dto/ubicacion.dto';
import { AsignarResponsableDto } from './dto/asignar-responsable.dto';
import { UpdateUnidadDto } from './dto/update-unidad.dto';
import { VerificarPlacaQueryDto } from './dto/verificar-placa-query.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';
import { RateLimitGuard } from '../common/guards/rate-limit.guard';

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

  /**
   * Verificacion publica de placa: el ciudadano que busca una unidad desde el
   * home no tiene cuenta. Solo devuelve codigo, tipo y placa; nunca estado,
   * responsable, ubicacion ni ultimaActualizacion (esos datos son operativos y
   * quedan detras de `GET /unidades`, que exige rol).
   */
  @Public()
  @UseGuards(RateLimitGuard)
  @ApiHeader({ name: 'Idempotency-Key', required: false, description: 'No se usa aqui; el guard lo ignora si no viene.' })
  @Get('verificar')
  verificar(@Query() q: VerificarPlacaQueryDto) {
    return this.svc.verificar(q.placa);
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get() findAll(@Query('placa') placa?: string) { return this.svc.findAll(placa); }

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

  @Roles('ADMIN', 'OPERADOR')
  @Patch(':id') actualizar(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateUnidadDto) {
    return this.svc.actualizar(id, dto);
  }

  // Baja logica: se conserva la unidad con eliminado_en marcado, fuera de los
  // listados. Solo ADMIN: borrar unidad es una decision administrativa.
  @Roles('ADMIN')
  @Delete(':id') eliminar(@Param('id', ParseUUIDPipe) id: string) { return this.svc.eliminar(id); }

  @Roles('ADMIN', 'OPERADOR', 'DIRECTIVO')
  @Get(':id/rastro')
  rastro(@Param('id', ParseUUIDPipe) id: string, @Query() q: RastroQueryDto) {
    return this.svc.rastro(id, q.limite);
  }
}