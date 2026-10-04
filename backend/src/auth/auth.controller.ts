import { Body, Controller, Get, HttpCode, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { LoginDto, LoginPatrulleroDto, RefreshDto } from './dto/login.dto';
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
  @Post('login/patrullero')
  @HttpCode(200)
  loginPatrullero(@Body() dto: LoginPatrulleroDto, @Req() req: Request) {
    // req.ip es la IP que Express resuelve; detras de un proxy conviene
    // activar 'trust proxy' en la app para que responda la IP real.
    return this.svc.loginPatrullero(dto, req.ip ?? 'desconocido');
  }

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