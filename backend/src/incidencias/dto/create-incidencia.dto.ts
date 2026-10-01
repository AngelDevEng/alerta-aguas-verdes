import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, MaxLength, IsDateString } from 'class-validator';
import { PRIORIDADES } from '../../common/enums';

export class CreateIncidenciaDto {
  @ApiProperty({ example: 1 }) @IsInt() tipoId: number;
  @ApiPropertyOptional() @IsOptional() @IsString() descripcion?: string;
  @ApiPropertyOptional({ enum: PRIORIDADES }) @IsOptional() @IsIn(PRIORIDADES as unknown as string[]) prioridad?: string;
  @ApiProperty({ example: -3.4825 }) @IsNumber() @IsLatitude() latitud: number;
  @ApiProperty({ example: -80.245 }) @IsNumber() @IsLongitude() longitud: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) referencia?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() ocurridoEn?: string;
}
