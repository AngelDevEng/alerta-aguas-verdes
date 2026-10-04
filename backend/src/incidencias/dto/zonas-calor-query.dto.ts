import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional, IsString } from 'class-validator';

/**
 * Filtros opcionales del mapa de calor.
 *
 * `tipo` acepta el codigo del catalogo (ROBO, RIA, SOSP, ACC, VIOL, RUIDO,
 * EMER) o el nombre exacto, sin importar mayusculas/minusculas.
 */
export class ZonasCalorQueryDto {
  @ApiPropertyOptional({ description: 'Fecha desde (ISO-8601)' })
  @IsOptional() @IsDateString() desde?: string;

  @ApiPropertyOptional({ description: 'Fecha hasta (ISO-8601)' })
  @IsOptional() @IsDateString() hasta?: string;

  @ApiPropertyOptional({ example: 'ROBO' })
  @IsOptional() @IsString() tipo?: string;
}
