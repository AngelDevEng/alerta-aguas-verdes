import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional, IsString } from 'class-validator';

export class EstadisticasQueryDto {
  @ApiPropertyOptional({ description: 'Fecha desde (ISO-8601)' })
  @IsOptional() @IsDateString() desde?: string;

  @ApiPropertyOptional({ description: 'Fecha hasta (ISO-8601)' })
  @IsOptional() @IsDateString() hasta?: string;

  @ApiPropertyOptional({ example: 'ROBO' })
  @IsOptional() @IsString() tipo?: string;

  @ApiPropertyOptional({ description: 'Zona/distrito' })
  @IsOptional() @IsString() zona?: string;
}
