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

const RATE_LIMIT_MS = 1000;
const MIN_LAT = -90;
const MAX_LAT = 90;
const MIN_LON = -180;
const MAX_LON = 180;

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

      const userId = payload.sub ?? payload.id;
      // Revalidar que el usuario siga activo en BD
      const rows = await this.ds.query(
        `SELECT id, activo FROM usuarios WHERE id = $1`,
        [userId],
      );
      if (!rows || rows.length === 0 || rows[0].activo === false) {
        socket.emit('error_auth', { message: 'Usuario inactivo o inexistente' });
        socket.disconnect(true);
        return;
      }

      const exp = payload.exp ? payload.exp * 1000 : Date.now() + 15 * 60 * 1000;
      socket.data.user = payload;
      socket.data.token = token;
      socket.data.tokenExp = exp;
      socket.data.lastPublish = 0;

      const rol = (payload.rol ?? '').toUpperCase();

      const salas: string[] = [];
      if (['OPERADOR', 'ADMIN', 'DIRECTIVO'].includes(rol)) {
        socket.join('central');
        salas.push('central');
      }
      if (['SERENO', 'ADMIN', 'OPERADOR'].includes(rol)) {
        socket.join('serenos');
        salas.push('serenos');
      }
      socket.join(`user:${userId}`);
      salas.push(`user:${userId}`);

      this.logger.log(`Cliente conectado: ${socket.id} (Rol: ${rol}, Salas: ${salas.join(', ')})`);
      socket.emit('conectado', {
        socketId: socket.id,
        user: { id: userId, dni: payload.dni, rol },
        salas,
        serverTime: new Date().toISOString(),
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

  @SubscribeMessage('ping_latencia')
  handlePing(@ConnectedSocket() socket: Socket, @MessageBody() data: any) {
    const serverTime = Date.now();
    socket.emit('pong_latencia', { clientSent: data?.t, serverTime, rtt: data?.t ? serverTime - data.t : undefined });
    return { serverTime };
  }

  @SubscribeMessage('posicion_unidad')
  async handlePosicionUnidad(
    @ConnectedSocket() socket: Socket,
    @MessageBody() data: { unidadId: string; latitud: number; longitud: number; velocidad?: number; rumbo?: number },
  ) {
    const user = socket.data.user;
    if (!user) return;

    // Token vencido en conexion abierta: cerrar y pedir refresh
    if (socket.data.tokenExp && Date.now() > socket.data.tokenExp) {
      socket.emit('error_auth', { message: 'Access token vencido; reconecta con refresh' });
      socket.disconnect(true);
      return;
    }

    const rol = (user.rol ?? '').toUpperCase();
    if (!['SERENO', 'OPERADOR', 'ADMIN'].includes(rol)) {
      socket.emit('error', { message: 'No tiene permisos para transmitir ubicacion' });
      return;
    }

    const { unidadId, latitud, longitud } = data || ({} as any);
    if (!unidadId || latitud == null || longitud == null) {
      socket.emit('error', { message: 'Datos de ubicacion incompletos' });
      return;
    }
    if (typeof latitud !== 'number' || typeof longitud !== 'number' ||
        latitud < MIN_LAT || latitud > MAX_LAT || longitud < MIN_LON || longitud > MAX_LON) {
      socket.emit('error', { message: 'Latitud/longitud fuera de rango' });
      return;
    }

    // Rate limit por conexion
    const now = Date.now();
    if (now - (socket.data.lastPublish || 0) < RATE_LIMIT_MS) {
      socket.emit('error', { message: 'Demasiadas publicaciones; espera un momento' });
      return;
    }

    // SERENO solo puede publicar la unidad asignada
    if (rol === 'SERENO') {
      const rows = await this.ds.query(
        `SELECT responsable_id FROM unidades_serenazgo WHERE id = $1`,
        [unidadId],
      );
      const responsable = rows?.[0]?.responsable_id;
      if (responsable !== (user.sub ?? user.id)) {
        socket.emit('error', { message: 'No tienes asignada esta unidad' });
        return;
      }
    }

    socket.data.lastPublish = now;

    // Revalidar usuario activo
    const urows = await this.ds.query(`SELECT activo FROM usuarios WHERE id = $1`, [user.sub ?? user.id]);
    if (!urows || urows.length === 0 || urows[0].activo === false) {
      socket.emit('error_auth', { message: 'Usuario inactivo' });
      socket.disconnect(true);
      return;
    }

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

    const serverTime = new Date().toISOString();
    const eventoPosicion = {
      unidadId,
      latitud,
      longitud,
      velocidad: data.velocidad ?? 0,
      rumbo: data.rumbo ?? 0,
      timestamp: serverTime,
      serverTime,
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
