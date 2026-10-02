import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto, RefreshDto } from './dto/login.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { UsuarioAutenticado } from '../common/types';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly svc: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(200)
  login(@Body() dto: LoginDto) { return this.svc.login(dto); }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  refrescar(@Body() dto: RefreshDto) { return this.svc.refrescar(dto.refreshToken); }

  @Post('logout')
  @HttpCode(200)
  logout(@Body() dto: RefreshDto) { return this.svc.cerrarSesion(dto.refreshToken); }

  @ApiBearerAuth()
  @Get('me')
  yo(@CurrentUser() u: UsuarioAutenticado) { return u; }
}