import { Injectable, Logger } from '@nestjs/common';
import { Server } from 'socket.io';

@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server: Server | null = null;

  setServer(server: Server) {
    this.server = server;
  }

  getServer(): Server | null {
    return this.server;
  }

  notificarNuevaAlerta(alerta: any) {
    if (!this.server) return;
    this.logger.log(`Emitiendo nueva_alerta_sos: ${alerta.incidenciaId ?? alerta.id}`);
    // Un mismo socket puede estar en ambas salas (OPERADOR/ADMIN); un array de
    // salas evita que reciba el evento dos veces.
    this.server.to(['central', 'serenos']).emit('nueva_alerta_sos', alerta);
  }

  notificarCambioEstadoIncidencia(incidencia: any) {
    if (!this.server) return;
    this.logger.log(`Emitiendo cambio_estado_incidencia: ${incidencia.id}`);
    this.server.to('central').emit('cambio_estado_incidencia', incidencia);
  }

  notificarCambioEstadoUnidad(unidad: any) {
    if (!this.server) return;
    this.logger.log(`Emitiendo cambio_estado_unidad: ${unidad.id}`);
    this.server.to('central').emit('cambio_estado_unidad', unidad);
  }

  notificarPosicionUnidad(posicion: any) {
    if (!this.server) return;
    this.server.to('central').emit('posicion_unidad', posicion);
  }
}
