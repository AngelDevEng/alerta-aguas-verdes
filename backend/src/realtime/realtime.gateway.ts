import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { Server, Socket } from 'socket.io';
import { RealtimeService } from './realtime.service';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/ws',
})
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly ds: DataSource,
    private readonly realtimeService: RealtimeService,
  ) {}

  afterInit(server: Server) {
    this.realtimeService.setServer(server);
    this.logger.log('Gateway de WebSockets /ws inicializado');
  }

  async handleConnection(socket: Socket) {
    try {
      const token = this.extraerToken(socket);
      if (!token) {
        this.logger.warn(`Conexion rechazada: Sin token JWT (${socket.id})`);
        socket.emit('error_auth', { message: 'Token JWT requerido' });
        socket.disconnect(true);
        return;
      }

      const secret = this.configService.getOrThrow<string>('JWT_SECRET');
      const payload = await this.jwtService.verifyAsync(token, { secret });

      socket.data.user = payload;
      const rol = (payload.rol ?? '').toUpperCase();

      // Control por rol: Asignacion de salas
      const salas: string[] = [];
      if (['OPERADOR', 'ADMIN', 'DIRECTIVO'].includes(rol)) {
        socket.join('central');
        salas.push('central');
      }
      if (['SERENO', 'ADMIN', 'OPERADOR'].includes(rol)) {
        socket.join('serenos');
        salas.push('serenos');
      }
      socket.join(`user:${payload.sub ?? payload.id}`);
      salas.push(`user:${payload.sub ?? payload.id}`);

      this.logger.log(`Cliente conectado: ${socket.id} (Rol: ${rol}, Salas: ${salas.join(', ')})`);
      socket.emit('conectado', {
        socketId: socket.id,
        user: { id: payload.sub ?? payload.id, dni: payload.dni, rol },
        salas,
      });
    } catch (err: any) {
      this.logger.warn(`Conexion rechazada: Token invalido/expirado (${socket.id}): ${err.message}`);
      socket.emit('error_auth', { message: 'Token JWT invalido o expirado' });
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket) {
    this.logger.log(`Cliente desconectado: ${socket.id}`);
  }

  @SubscribeMessage('posicion_unidad')
  async handlePosicionUnidad(
    @ConnectedSocket() socket: Socket,
    @MessageBody() data: { unidadId: string; latitud: number; longitud: number; velocidad?: number; rumbo?: number },
  ) {
    const user = socket.data.user;
    if (!user) return;

    const rol = (user.rol ?? '').toUpperCase();
    if (!['SERENO', 'OPERADOR', 'ADMIN'].includes(rol)) {
      socket.emit('error', { message: 'No tiene permisos para transmitir ubicacion' });
      return;
    }

    const { unidadId, latitud, longitud } = data;
    if (!unidadId || latitud == null || longitud == null) {
      socket.emit('error', { message: 'Datos de ubicacion incompletos' });
      return;
    }

    // Persistir ultima posicion en BD de forma eficiente
    try {
      await this.ds.query(
        `UPDATE unidades_serenazgo
            SET ultima_ubicacion = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
                ultima_actualizacion = NOW()
          WHERE id = $3`,
        [longitud, latitud, unidadId],
      );

      await this.ds.query(
        `INSERT INTO ubicaciones_unidad (unidad_id, ubicacion)
         VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography)`,
        [unidadId, longitud, latitud],
      );
    } catch (e: any) {
      this.logger.error(`Error al guardar ubicacion de unidad ${unidadId}: ${e.message}`);
    }

    // Emitir en tiempo real a la central
    const eventoPosicion = {
      unidadId,
      latitud,
      longitud,
      velocidad: data.velocidad ?? 0,
      rumbo: data.rumbo ?? 0,
      timestamp: new Date().toISOString(),
      reportadoPor: user.sub ?? user.id,
    };

    this.server.to('central').emit('posicion_unidad', eventoPosicion);
    return eventoPosicion;
  }

  private extraerToken(socket: Socket): string | null {
    const authHeader = socket.handshake.headers?.authorization;
    if (authHeader) {
      const parts = authHeader.split(' ');
      if (parts.length === 2 && parts[0].toLowerCase() === 'bearer') {
        return parts[1];
      }
      return authHeader;
    }

    if (socket.handshake.auth?.token) {
      return socket.handshake.auth.token;
    }

    if (socket.handshake.query?.token) {
      return socket.handshake.query.token as string;
    }

    return null;
  }
}
