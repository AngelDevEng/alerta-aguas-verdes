import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { memoryStorage } from 'multer';
import { EvidenciasService } from './evidencias.service';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsuarioAutenticado } from '../common/types';

@ApiTags('evidencias')
@ApiBearerAuth()
@Controller('incidencias/:id/evidencias')
export class EvidenciasController {
  constructor(private readonly svc: EvidenciasService) {}

  @Roles('SERENO', 'OPERADOR', 'ADMIN')
  @Post()
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: {
    archivo: { type: 'string', format: 'binary' }, latitud: { type: 'number' }, longitud: { type: 'number' } } } })
  @UseInterceptors(FileInterceptor('archivo', { storage: memoryStorage(), limits: { fileSize: 15 * 1024 * 1024 } }))
  subir(@Param('id', ParseUUIDPipe) id: string, @UploadedFile() archivo: Express.Multer.File,
        @Body('latitud') lat: string, @Body('longitud') lon: string,
        @CurrentUser() u: UsuarioAutenticado) {
    return this.svc.subir(id, archivo, lat ? Number(lat) : undefined, lon ? Number(lon) : undefined, u.id);
  }

  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get() listar(@Param('id', ParseUUIDPipe) id: string) { return this.svc.listar(id); }
}