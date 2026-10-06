import { ApiProperty } from '@nestjs/swagger';

/**
 * Forma unica de todos los errores del API.
 *
 * Se devuelve identica en 401, 403, 404 y 500 para que el cliente pueda
 * parsear un unico formato. Los dos ultimos campos son alias:
 *
 * - `mensaje` (string, nunca null ni array): lo leen la app Kotlin legacy en
 *   los logins de ciudadano y serenazgo, y el cliente Flutter.
 * - `message`: lo lee el login de admin del legacy (`optString("message")`).
 *   El legacy era inconsistente consigo mismo, asi que se sirven los dos.
 *
 * `mensajes` conserva la lista completa cuando hay varios fallos de
 * validacion, porque ahi un unico string perderia informacion.
 */
export class RespuestaErrorDto {
  @ApiProperty({ example: false })
  success: false;

  @ApiProperty({ example: 401 })
  statusCode: number;

  @ApiProperty({ description: 'Mensaje principal, siempre string.', example: 'Credenciales invalidas' })
  mensaje: string;

  @ApiProperty({ description: 'Alias de mensaje, en ingles, para el login admin del legacy.', example: 'Credenciales invalidas' })
  message: string;

  @ApiProperty({ type: [String], description: 'Todos los mensajes, useful con validacion.', example: ['Credenciales invalidas'] })
  mensajes: string[];

  @ApiProperty({ example: '/api/v1/auth/login' })
  ruta: string;
}