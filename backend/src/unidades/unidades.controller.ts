import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { UnidadesService } from './unidades.service';
import { CreateUnidadDto } from './dto/create-unidad.dto';
import { CercanasQueryDto, EstadoUnidadDto, UbicacionDto } from './dto/ubicacion.dto';

@ApiTags('unidades')
@Controller('unidades')
export class UnidadesController {
  constructor(private readonly svc: UnidadesService) {}

  @Post() create(@Body() dto: CreateUnidadDto) { return this.svc.create(dto); }
  @Get() findAll() { return this.svc.findAll(); }
  @Get('cercanas') cercanas(@Query() q: CercanasQueryDto) { return this.svc.cercanas(q.lon, q.lat, q.radio); }
  @Get(':id') findOne(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  @Post(':id/ubicaciones')
  ubicacion(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UbicacionDto) {
    return this.svc.registrarUbicacion(id, dto);
  }

  @Patch(':id/estado')
  estado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: EstadoUnidadDto) {
    return this.svc.cambiarEstado(id, dto.estado);
  }
}
