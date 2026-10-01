-- =====================================================================
-- Alerta Aguas Verdes - Modelo relacional PostgreSQL + PostGIS
-- Sprint 1 (H1) y Sprint 2 (H2)  |  Compatible con Supabase
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()

-- ---------- Tipos enumerados ----------
CREATE TYPE estado_incidencia AS ENUM ('REGISTRADA','DESPACHADA','EN_ATENCION','ATENDIDA','CANCELADA');
CREATE TYPE prioridad_nivel   AS ENUM ('BAJA','MEDIA','ALTA','CRITICA');
CREATE TYPE tipo_unidad       AS ENUM ('PATRULLA','MOTOCICLETA','PIE');
CREATE TYPE estado_unidad     AS ENUM ('DISPONIBLE','OCUPADA','FUERA_SERVICIO');
CREATE TYPE tipo_evidencia    AS ENUM ('FOTO','VIDEO','AUDIO');

-- ---------- Catalogos ----------
CREATE TABLE roles (
  id      SMALLSERIAL PRIMARY KEY,
  nombre  VARCHAR(30) NOT NULL UNIQUE          -- ADMIN, OPERADOR, SERENO, DIRECTIVO
);

CREATE TABLE tipos_incidencia (
  id         SMALLSERIAL PRIMARY KEY,
  codigo     VARCHAR(20)  NOT NULL UNIQUE,
  nombre     VARCHAR(80)  NOT NULL,
  prioridad  prioridad_nivel NOT NULL DEFAULT 'MEDIA',
  activo     BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------- Usuarios ----------
CREATE TABLE usuarios (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dni            CHAR(8)      NOT NULL UNIQUE,
  nombres        VARCHAR(80)  NOT NULL,
  apellidos      VARCHAR(80)  NOT NULL,
  email          VARCHAR(120) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  rol_id         SMALLINT     NOT NULL REFERENCES roles(id),
  activo         BOOLEAN      NOT NULL DEFAULT TRUE,
  creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_dni_numerico CHECK (dni ~ '^[0-9]{8}$')
);

-- ---------- Unidades de serenazgo ----------
CREATE TABLE unidades_serenazgo (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo              VARCHAR(20) NOT NULL UNIQUE,          -- p. ej. SER-01
  tipo                tipo_unidad NOT NULL,
  placa               VARCHAR(10) UNIQUE,
  estado              estado_unidad NOT NULL DEFAULT 'DISPONIBLE',
  responsable_id      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  ultima_ubicacion    GEOGRAPHY(Point,4326),
  ultima_actualizacion TIMESTAMPTZ,
  creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Incidencias ----------
CREATE SEQUENCE seq_codigo_incidencia START 1;

CREATE TABLE incidencias (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo             VARCHAR(20) NOT NULL UNIQUE
                       DEFAULT ('INC-' || to_char(now(),'YYYY') || '-' || lpad(nextval('seq_codigo_incidencia')::text,6,'0')),
  tipo_id            SMALLINT NOT NULL REFERENCES tipos_incidencia(id),
  descripcion        TEXT,
  estado             estado_incidencia NOT NULL DEFAULT 'REGISTRADA',
  prioridad          prioridad_nivel   NOT NULL DEFAULT 'MEDIA',
  ubicacion          GEOGRAPHY(Point,4326) NOT NULL,       -- (lon, lat)
  referencia         VARCHAR(200),
  reportado_por      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  unidad_asignada_id UUID REFERENCES unidades_serenazgo(id) ON DELETE SET NULL,
  ocurrido_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
  atendido_en        TIMESTAMPTZ,
  creado_en          TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_coord_validas CHECK (
    ST_Y(ubicacion::geometry) BETWEEN -90 AND 90 AND ST_X(ubicacion::geometry) BETWEEN -180 AND 180),
  CONSTRAINT chk_atencion_coherente CHECK (atendido_en IS NULL OR atendido_en >= ocurrido_en)
);

-- ---------- Evidencias multimedia (H2) ----------
CREATE TABLE evidencias_multimedia (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incidencia_id  UUID NOT NULL REFERENCES incidencias(id) ON DELETE CASCADE,
  tipo           tipo_evidencia NOT NULL DEFAULT 'FOTO',
  storage_path   VARCHAR(300) NOT NULL UNIQUE,            -- ruta en Supabase Storage
  url_publica    TEXT,
  mime_type      VARCHAR(80)  NOT NULL,
  tamano_bytes   BIGINT       NOT NULL CHECK (tamano_bytes > 0),
  hash_sha256    CHAR(64)     NOT NULL,                   -- integridad / cadena de custodia
  ubicacion      GEOGRAPHY(Point,4326),
  capturado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  subido_por     UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_evidencia_hash UNIQUE (incidencia_id, hash_sha256)
);

-- ---------- Trazabilidad de estados ----------
CREATE TABLE historial_incidencia (
  id              BIGSERIAL PRIMARY KEY,
  incidencia_id   UUID NOT NULL REFERENCES incidencias(id) ON DELETE CASCADE,
  estado_anterior estado_incidencia,
  estado_nuevo    estado_incidencia NOT NULL,
  unidad_id       UUID REFERENCES unidades_serenazgo(id) ON DELETE SET NULL,
  usuario_id      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  registrado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Recorrido GPS de unidades (H2) ----------
CREATE TABLE ubicaciones_unidad (
  id            BIGSERIAL PRIMARY KEY,
  unidad_id     UUID NOT NULL REFERENCES unidades_serenazgo(id) ON DELETE CASCADE,
  ubicacion     GEOGRAPHY(Point,4326) NOT NULL,
  velocidad_kmh NUMERIC(5,1) CHECK (velocidad_kmh >= 0),
  registrado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
