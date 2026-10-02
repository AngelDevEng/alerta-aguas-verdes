import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ESTADOS_UNIDAD } from '../../common/enums';

export class UbicacionDto {
  @ApiProperty() @IsNumber() @IsLatitude() latitud: number;
  @ApiProperty() @IsNumber() @IsLongitude() longitud: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) velocidadKmh?: number;
}

export class EstadoUnidadDto {
  @ApiProperty({ enum: ESTADOS_UNIDAD }) @IsIn(ESTADOS_UNIDAD as unknown as string[]) estado: string;
}

export class CercanasQueryDto {
  @ApiProperty() @Type(() => Number) @IsNumber() @IsLatitude() lat: number;
  @ApiProperty() @Type(() => Number) @IsNumber() @IsLongitude() lon: number;
  @ApiPropertyOptional({ default: 2000 }) @IsOptional() @Type(() => Number) @IsNumber() @Min(1) radio = 2000;
}

export class RastroQueryDto {
  @ApiPropertyOptional({ default: 200, maximum: 2000 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(2000) limite = 200;
}
