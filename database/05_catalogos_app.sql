-- =====================================================================
-- Catálogos para cerrar huecos con la app legacy (Android/Kotlin)
-- Asociaciones (clientes legacy) y Central telefónica (emergencias)
-- =====================================================================

-- ---------- Asociaciones (tabla clientes legacy) ----------
CREATE TABLE IF NOT EXISTS asociaciones (
  id     SMALLSERIAL PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO asociaciones(nombre) VALUES
  ('Dios con Nosotros'),
  ('Central de Trabajadores'),
  ('Shalom Dios con Nosotros'),
  ('Obra Misionera de las Asambleas de Dios del Peru'),
  ('Asociacion de Propietarios la Union'),
  ('Asociacion de Familiares de la Congregacion Evangelica Pentecostes'),
  ('Asociacion de Vivienda Central Ciudad Nueva'),
  ('Asociacion de Vivienda 24 de Junio'),
  ('Asociacion de Vivienda Valle Hermoso'),
  ('Asociacion de Vivienda Lomas de los Heroes'),
  ('Asociacion de Vivienda Manuel Seoane Corrales'),
  ('Asociacion de Vivienda Los Laureles'),
  ('Asociacion de Vivienda Orellana'),
  ('Asociacion de Vivienda Jesus es mi Fortaleza'),
  ('Asociacion de Vivienda Alameda'),
  ('Asociacion de Vivienda San Jose'),
  ('Asociacion de Vivienda Las Mercedes'),
  ('Asociacion de Vivienda Virgen de Guadalupe'),
  ('Asociacion de Vivienda Virreyna'),
  ('Asociacion de Vivienda Julio C. Tello'),
  ('Asociacion de Vivienda Las Palmeras'),
  ('Asociacion de Vivienda Andres Avelino Caceres'),
  ('Asociacion de Vivienda Cristo Rey'),
  ('Asociacion de Vivienda San Pedro'),
  ('Asociacion de Vivienda Maria Parado de Bellido')
ON CONFLICT (nombre) DO NOTHING;

-- ---------- Central telefónica / contactos de emergencia ----------
CREATE TABLE IF NOT EXISTS contactos_emergencia (
  id          SMALLSERIAL PRIMARY KEY,
  nombre      VARCHAR(80) NOT NULL,
  telefono    VARCHAR(20) NOT NULL,
  es_whatsapp BOOLEAN NOT NULL DEFAULT FALSE,
  orden       SMALLINT NOT NULL DEFAULT 1,
  activo      BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_contacto_nombre_activo UNIQUE (nombre, activo)
);

-- Semilla alineada con EmergenciaActivity (Android)
INSERT INTO contactos_emergencia(nombre, telefono, es_whatsapp, orden, activo) VALUES
  ('Comisaría PNP', '51957822184', FALSE, 1, TRUE),
  ('CLAS Aguas Verdes', '51949520508', FALSE, 2, TRUE),
  ('Bomberos', '51972561385', FALSE, 3, TRUE),
  ('Alcalde MDAV', '51937733255', FALSE, 4, TRUE),
  ('Serenazgo', '51967404172', FALSE, 5, TRUE),
  ('WhatsApp Serenazgo', '51967404172', TRUE, 6, TRUE),
  ('Reporta tu incidencia (WhatsApp)', '51990374607', TRUE, 7, TRUE),
  ('GPS (referencia legacy)', '914277115', FALSE, 8, TRUE)
ON CONFLICT DO NOTHING;