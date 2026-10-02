import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export const ESTADOS_ALERTA = ['ACTIVA', 'ATENDIDA', 'CANCELADA', 'FALSA'] as const;

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