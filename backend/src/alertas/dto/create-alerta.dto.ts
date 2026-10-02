import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export const ORIGENES_ALERTA = ['APP', 'WEB', 'SMS', 'LLAMADA'] as const;

export class CreateAlertaDto {
  @ApiProperty({ example: -3.4825 })
  @IsNumber() @IsLatitude() latitud: number;

  @ApiProperty({ example: -80.245 })
  @IsNumber() @IsLongitude() longitud: number;

  @ApiPropertyOptional({ description: 'Numero del reportante; es la unica via de retorno si no hay sesion iniciada.' })
  @IsOptional() @IsString() @MaxLength(20) telefono?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(200) direccion?: string;

  @ApiPropertyOptional({ description: 'Precision GPS en metros' })
  @IsOptional() @IsNumber() @Min(0) precisionM?: number;

  @ApiPropertyOptional({ enum: ORIGENES_ALERTA, default: 'APP' })
  @IsOptional() @IsIn(ORIGENES_ALERTA as unknown as string[]) origen?: string;
}