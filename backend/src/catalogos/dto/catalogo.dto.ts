import { ApiProperty } from '@nestjs/swagger';

export class CatalogoItemDto {
  @ApiProperty() id: number;
  @ApiProperty() nombre: string;
}