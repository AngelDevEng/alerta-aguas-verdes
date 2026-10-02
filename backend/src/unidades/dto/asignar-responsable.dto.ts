import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class AsignarResponsableDto {
  @ApiPropertyOptional({ description: 'Usuario sereno responsable. Null para liberar la unidad.' })
  @IsOptional() @IsUUID('4') usuarioId?: string;
}