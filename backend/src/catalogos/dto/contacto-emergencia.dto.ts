import { ApiProperty } from '@nestjs/swagger';

export class ContactoEmergenciaDto {
  @ApiProperty() id: number;
  @ApiProperty() nombre: string;
  @ApiProperty() telefono: string;
  @ApiProperty({ name: 'esWhatsapp' }) esWhatsapp: boolean;
  @ApiProperty() orden: number;
  @ApiProperty() activo: boolean;
}