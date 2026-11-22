import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export const ESTADOS_ALERTA = [
  'ACTIVA',
  'ACEPTADA',
  'ATENDIDA',
  'CANCELADA',
  'FALSA',
  'EXPIRADA',
] as const;

export class EstadoAlertaDto {
  @ApiProperty({ enum: ESTADOS_ALERTA })
  @IsIn(ESTADOS_ALERTA as unknown as string[]) estado: string;
}

export class ListarAlertasQueryDto {
  @ApiPropertyOptional({ enum: ESTADOS_ALERTA })
  @IsOptional() @IsString() estado?: string;

  @ApiPropertyOptional({ default: 100, maximum: 500 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(500) limite = 100;
}

export class PosicionCiudadanoDto {
  @ApiProperty({ example: -3.4825 })
  @IsNumber() @IsLatitude() latitud!: number;

  @ApiProperty({ example: -80.245 })
  @IsNumber() @IsLongitude() longitud!: number;

  @ApiPropertyOptional()
  @IsOptional() @IsNumber() @Min(0) velocidadKmh?: number;
}