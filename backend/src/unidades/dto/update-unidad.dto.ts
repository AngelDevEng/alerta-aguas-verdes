import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { TIPOS_UNIDAD } from '../../common/enums';

/**
 * Campos editables de una unidad ya creada. Todos opcionales: el PATCH solo
 * actualiza lo que viene informado.
 */
export class UpdateUnidadDto {
  @ApiPropertyOptional({ example: 'SER-04' })
  @IsOptional() @IsString() @MaxLength(20) codigo?: string;

  @ApiPropertyOptional({ enum: TIPOS_UNIDAD })
  @IsOptional() @IsIn(TIPOS_UNIDAD as unknown as string[]) tipo?: string;

  @ApiPropertyOptional({ example: 'EGA-456' })
  @IsOptional() @IsString() @MaxLength(10) placa?: string;
}
