import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import { ESTADOS_INCIDENCIA } from '../../common/enums';

export class CambiarEstadoDto {
  @ApiProperty({ enum: ESTADOS_INCIDENCIA })
  @IsIn(ESTADOS_INCIDENCIA as unknown as string[])
  estado: string;
}
