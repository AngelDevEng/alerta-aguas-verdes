import { Body, Controller, Get, Headers, Ip, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiTags } from '@nestjs/swagger';
import { AlertasService } from './alertas.service';
import { CreateAlertaDto } from './dto/create-alerta.dto';
import { EstadoAlertaDto, ListarAlertasQueryDto, PosicionCiudadanoDto } from './dto/estado-alerta.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';
import { RateLimitGuard } from '../common/guards/rate-limit.guard';

@ApiTags('alertas')
@ApiBearerAuth()
@Controller('alertas')
export class AlertasController {
  constructor(private readonly svc: AlertasService) {}

  /**
   * Unico endpoint publico a proposito: el ciudadano que pulsa SOS no tiene cuenta.
   * No se expone ningun dato del reporte mas alla de lo que el propio usuario envia.
   *
   * `X-Device-Id` permite una sola SOS activa por dispositivo; `X-Session-Token`
   * no se recibe aca: el token viaja en el cuerpo de la respuesta.
   *
   * `Idempotency-Key` (opcional) hace que un reintento con la misma clave y el
   * mismo `X-Device-Id` devuelva la alerta ya creada en vez de duplicarla. La
   * clave debe ser estable por envio (UUID v4) y distinta en cada SOS nueva.
   */
  @Public()
  @UseGuards(RateLimitGuard)
  @ApiHeader({ name: 'X-Device-Id', required: false, description: 'Identificador estable del dispositivo.' })
  @ApiHeader({ name: 'Idempotency-Key', required: false, description: 'Clave estable por envio; un reintento devuelve la alerta original.' })
  @Post()
  crear(
    @Body() dto: CreateAlertaDto,
    @Headers('x-device-id') dispositivoId?: string,
    @Headers('idempotency-key') idempotencyKey?: string,
    @Ip() ip?: string,
    @CurrentUser() u?: UsuarioAutenticado,
  ) {
    return this.svc.crear(dto, u?.id, dispositivoId, ip, idempotencyKey);
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get()
  listar(@Query() q: ListarAlertasQueryDto) { return this.svc.listar(q.estado, q.limite); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get('activas')
  activas(@CurrentUser() u: UsuarioAutenticado) { return this.svc.activasParaUsuario(u); }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get(':id')
  una(@Param('id', ParseUUIDPipe) id: string) { return this.svc.findOne(id); }

  /**
   * Seguimiento del ciudadano. Publico pero no abierto: exige el token anonimo
   * que solo se entrego al crear (o reutilizar) esa alerta.
   */
  @Public()
  @Get(':id/seguimiento')
  seguimiento(
    @Param('id', ParseUUIDPipe) id: string,
    @Headers('x-session-token') token?: string,
  ) {
    return this.svc.seguimiento(id, token);
  }

  /**
   * El ciudadano publica su ubicacion mientras la SOS siga activa. Autenticado
   * por el token anonimo de seguimiento, no por JWT.
   */
  @Public()
  @Post(':id/posicion')
  posicionCiudadano(
    @Param('id', ParseUUIDPipe) id: string,
    @Headers('x-session-token') token: string | undefined,
    @Body() dto: PosicionCiudadanoDto,
  ) {
    return this.svc.registrarPosicionCiudadano(
      id,
      token,
      dto.latitud,
      dto.longitud,
      dto.velocidadKmh,
    );
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN')
  @Patch(':id/estado')
  cambiarEstado(@Param('id', ParseUUIDPipe) id: string, @Body() dto: EstadoAlertaDto, @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.cambiarEstado(id, dto.estado, u);
  }
}