import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '00000001', description: 'DNI de 8 digitos' })
  @IsString() @Matches(/^[0-9]{8}$/, { message: 'El dni debe tener 8 digitos numericos' })
  dni: string;

  @ApiProperty({ example: 'mi-contrasena-segura', writeOnly: true })
  @IsString() @IsNotEmpty() @MaxLength(72)
  password: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString() @IsNotEmpty()
  refreshToken: string;
}

/**
 * Login de un sereno por placa de su unidad asignada.
 *
 * La placa se normaliza antes de comparar (mayusculas, sin espacios ni
 * guiones), porque el operador la teclea desde un celular y el backend la
 * guarda como 'EGA-123' pero suele llegar como 'ega-123'.
 */
export class LoginPatrulleroDto {
  @ApiProperty({ example: 'EGA-123', description: 'Placa de la unidad asignada al sereno' })
  @IsString() @Matches(/^[A-Za-z0-9\-\s]{4,10}$/, { message: 'Formato de placa invalido' })
  placa: string;

  @ApiProperty({ example: 'mi-contrasena-segura', writeOnly: true })
  @IsString() @IsNotEmpty() @MaxLength(72)
  password: string;
}