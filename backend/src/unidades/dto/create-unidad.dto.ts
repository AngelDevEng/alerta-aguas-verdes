import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { TIPOS_UNIDAD } from '../../common/enums';

export class CreateUnidadDto {
  @ApiProperty({ example: 'SER-04' }) @IsString() @MaxLength(20) codigo: string;
  @ApiProperty({ enum: TIPOS_UNIDAD }) @IsIn(TIPOS_UNIDAD as unknown as string[]) tipo: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) placa?: string;
}
