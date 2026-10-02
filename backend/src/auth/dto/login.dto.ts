import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '00000001', description: 'DNI de 8 digitos' })
  @IsString() @Matches(/^[0-9]{8}$/, { message: 'El dni debe tener 8 digitos numericos' })
  dni: string;

  @ApiProperty({ example: 'CambiarEsto.2026' })
  @IsString() @IsNotEmpty() @MaxLength(72)
  password: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString() @IsNotEmpty()
  refreshToken: string;
}