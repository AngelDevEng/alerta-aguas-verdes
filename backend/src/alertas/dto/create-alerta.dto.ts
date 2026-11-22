import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsBoolean, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, MaxLength, Min, ValidateIf } from 'class-validator';

export const ORIGENES_ALERTA = ['APP', 'WEB', 'SMS', 'LLAMADA'] as const;

export class CreateAlertaDto {
  @ApiProperty({
    example: -3.4825,
    description:
      'Latitud del SOS. Obligatoria salvo que sinUbicacion sea true; en ese '
      + 'caso la app envia 0 y el backend marca la alerta como sin ubicacion.',
  })
  @ValidateIf((o: CreateAlertaDto) => o.sinUbicacion !== true)
  @IsNumber()
  @IsLatitude()
  latitud!: number;

  @ApiProperty({
    example: -80.245,
    description:
      'Longitud del SOS. Obligatoria salvo que sinUbicacion sea true.',
  })
  @ValidateIf((o: CreateAlertaDto) => o.sinUbicacion !== true)
  @IsNumber()
  @IsLongitude()
  longitud!: number;

  @ApiPropertyOptional({ description: 'Numero del reportante; es la unica via de retorno si no hay sesion iniciada.' })
  @IsOptional() @IsString() @MaxLength(20) telefono?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(200) direccion?: string;

  @ApiPropertyOptional({ description: 'Precision GPS en metros' })
  @IsOptional() @IsNumber() @Min(0) precisionM?: number;

  @ApiPropertyOptional({ enum: ORIGENES_ALERTA, default: 'APP' })
  @IsOptional() @IsIn(ORIGENES_ALERTA as unknown as string[]) origen?: string;

  @ApiPropertyOptional({
    description:
      'True cuando el dispositivo no pudo obtener ubicacion. La alerta se crea '
      + 'igual (perder el SOS es peor que no tener coordenadas): se marca la '
      + 'direccion como "Sin ubicacion" y se omite la precision.',
    default: false,
  })
  @IsOptional() @IsBoolean() sinUbicacion?: boolean;
}