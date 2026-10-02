import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AlertasService } from './alertas.service';
import { CreateAlertaDto } from './dto/create-alerta.dto';
import { EstadoAlertaDto, ListarAlertasQueryDto } from './dto/estado-alerta.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';

@ApiTags('alertas')
@ApiBearerAuth()
@Controller('alertas')
export class AlertasController {
  constructor(private readonly svc: AlertasService) {}

  /**
   * Unico endpoint publico a proposito: el ciudadano que pulsa SOS no tiene cuenta.
   * No se expone ningun dato del reporte mas alla de lo que el propio usuario envia.
   */
  @Public()
  @Post()
  crear(@Body() dto: CreateAlertaDto, @CurrentUser() u?: UsuarioAutenticado) {
    return this.svc.crear(dto, u?.id);
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get()
  listar(@Query() q: ListarAlertasQueryDto) { return this.svc.listar(q.estado, q.limite); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get('activas')
  activas() { return this.svc.activas(); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get(':id')
  una(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN')
  @Patch(':id/estado')
  cambiarEstado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: EstadoAlertaDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.cambiarEstado(id, dto.estado, u.id);
  }
}