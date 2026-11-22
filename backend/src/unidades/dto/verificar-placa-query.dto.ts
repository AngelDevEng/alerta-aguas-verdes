import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

export class VerificarPlacaQueryDto {
  @ApiProperty({
    description:
      'Placa exacta a verificar (normalizada por el cliente: sin espacios, '
      + 'mayusculas). El backend responde solo si coincide una unidad activa.',
    example: 'EGA-123',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(20)
  placa!: string;
}