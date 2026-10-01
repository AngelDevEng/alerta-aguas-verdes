import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class AsignarUnidadDto {
  @ApiProperty() @IsUUID() unidadId: string;
}
