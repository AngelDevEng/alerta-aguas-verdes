import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CatalogosService } from './catalogos.service';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('catalogos')
@Controller('catalogos')
export class CatalogosController {
  constructor(private readonly svc: CatalogosService) {}

  @ApiBearerAuth()
  @Roles('SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO')
  @Get('asociaciones')
  asociaciones() {
    return this.svc.asociaciones();
  }

  @Public()
  @Get('emergencias')
  emergencias() {
    return this.svc.emergencias();
  }

  @Public()
  @Get('emergencias/whatsapp')
  whatsapp() {
    return this.svc.whatsapp();
  }
}