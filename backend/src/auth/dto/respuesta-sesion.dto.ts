import { ApiProperty } from '@nestjs/swagger';

/**
 * Forma de la respuesta de `POST /auth/login` y `POST /auth/refresh`.
 *
 * Dos clientes conviven y esperan nombres distintos, asi que se devuelven
 * ambos a la vez en lugar de forzar a uno a adaptedarse:
 *
 * - App Kotlin legacy (`InicioActivity.kt`): lee `token`, `nombre`, `success`
 *   y `message` con `JSONObject.getString`/`optString`, que lanza excepcion si
 *   la clave no existe. Por eso todos estos campos son strings no nulos.
 * - Cliente Flutter (`auth_dto.dart`): lee `accessToken`, `refreshToken`,
 *   `expiresIn` y el objeto anidado `usuario`.
 *
 * `token` y `accessToken` son el mismo JWT. `nombre` y `nombreCompleto` tambien.
 */
export class RespuestaSesionDto {
  @ApiProperty({ description: 'Siempre true cuando el login es correcto', example: true })
  success: boolean;

  @ApiProperty({ description: 'JWT de acceso. Alias de accessToken, usado por la app Kotlin legacy.' })
  token: string;

  @ApiProperty({ description: 'JWT de acceso. Mismo valor que token.' })
  accessToken: string;

  @ApiProperty({ description: 'Refresh token opaco de un solo uso, rotativo.' })
  refreshToken: string;

  @ApiProperty({ example: 'Bearer' })
  tokenType: string;

  @ApiProperty({ description: 'Segundos de validez del access token', example: 900 })
  expiresIn: number;

  @ApiProperty({ description: 'UUID del usuario. String para no romper el cast del cliente.', example: '6fd7d91c-f0f9-4c21-a159-7fc074632850' })
  id: string;

  @ApiProperty({ example: '00000002' })
  dni: string;

  @ApiProperty({ description: 'Nombre completo del usuario. Alias de usuario.nombreCompleto.', example: 'Admin Municipal' })
  nombre: string;

  @ApiProperty({ example: 'ADMIN' })
  rol: string;

  @ApiProperty({ example: 'admin@muniaguasverdes.gob.pe', nullable: true })
  email: string | null;

  @ApiProperty({ description: 'Mismo usuario anidado, que es lo que lee el cliente Flutter.' })
  usuario: {
    id: string;
    dni: string;
    nombreCompleto: string;
    email: string | null;
    rol: string;
  };
}