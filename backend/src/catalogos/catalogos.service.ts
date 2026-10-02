import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class CatalogosService {
  constructor(private readonly ds: DataSource) {}

  asociaciones() {
    return this.ds.query(
      `SELECT id, nombre FROM asociaciones WHERE activo = TRUE ORDER BY nombre`,
    );
  }

  emergencias() {
    return this.ds.query(
      `SELECT id, nombre, telefono, es_whatsapp AS "esWhatsapp", orden, activo
         FROM contactos_emergencia
        WHERE activo = TRUE
        ORDER BY orden, id`,
    );
  }

  whatsapp() {
    return this.ds.query(
      `SELECT id, nombre, telefono, es_whatsapp AS "esWhatsapp", orden
         FROM contactos_emergencia
        WHERE activo = TRUE AND es_whatsapp = TRUE
        ORDER BY orden, id`,
    );
  }
}