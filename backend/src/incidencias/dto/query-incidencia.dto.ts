import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';
import { ESTADOS_INCIDENCIA } from '../../common/enums';

export class QueryIncidenciaDto {
  @ApiPropertyOptional({ enum: ESTADOS_INCIDENCIA }) @IsOptional() @IsIn(ESTADOS_INCIDENCIA as unknown as string[]) estado?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() tipoId?: number;
  @ApiPropertyOptional() @IsOptional() @IsDateString() desde?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() hasta?: string;
  @ApiPropertyOptional({ default: 1 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @ApiPropertyOptional({ default: 20 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
}
