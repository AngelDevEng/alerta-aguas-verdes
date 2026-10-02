-- =====================================================================
-- Alerta Aguas Verdes - Autenticacion, roles y alertas SOS
-- Ejecutar DESPUES de 01, 02 y 03.  Idempotente donde es posible.
-- =====================================================================

-- ---------- Nuevos roles ----------
INSERT INTO roles(nombre) VALUES ('CIUDADANO')
  ON CONFLICT (nombre) DO NOTHING;

-- ---------- Telefono del usuario (canal de contacto en SOS) ----------
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS telefono VARCHAR(20);

-- ---------- Refresh tokens ----------
-- El access token es JWT corto (15 min). El refresh es opaco, se guarda
-- solo su SHA-256 para que una filtracion de la BD no sirva para autenticarse.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token_hash  CHAR(64) NOT NULL UNIQUE,
  expira_en   TIMESTAMPTZ NOT NULL,
  revocado    BOOLEAN NOT NULL DEFAULT FALSE,
  creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_usuario ON refresh_tokens(usuario_id);
CREATE INDEX IF NOT EXISTS idx_refresh_expira  ON refresh_tokens(expira_en);

-- ---------- Alertas SOS ----------
-- El legado (apis/crear_alerta.php) usaba una tabla `alertas` que no existe
-- en ningun dump. Aqui se modela explicitamente y ademas genera la incidencia
-- CRITICA asociada, de modo que el SOS entra al flujo normal de despacho.
CREATE TABLE IF NOT EXISTS alertas (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incidencia_id     UUID REFERENCES incidencias(id) ON DELETE SET NULL,
  reportante_id     UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  telefono          VARCHAR(20),
  ubicacion         GEOGRAPHY(Point,4326) NOT NULL,
  direccion         VARCHAR(200),
  precision_m       NUMERIC(8,1),
  origen            VARCHAR(20) NOT NULL DEFAULT 'APP'
                    CHECK (origen IN ('APP','WEB','SMS','LLAMADA')),
  estado            VARCHAR(15) NOT NULL DEFAULT 'ACTIVA'
                    CHECK (estado IN ('ACTIVA','ATENDIDA','CANCELADA','FALSA')),
  atendida_por      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  atendida_en       TIMESTAMPTZ,
  notas             TEXT,
  creada_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_atencion_alerta CHECK (atendida_en IS NULL OR atendida_en >= creada_en)
);

CREATE INDEX IF NOT EXISTS idx_alertas_estado ON alertas(estado, creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_alertas_ubicacion ON alertas(ubicacion);
CREATE INDEX IF NOT EXISTS idx_alertas_telefono ON alertas(telefono);

-- Vista de alertas vivas para la sala de despacho
CREATE OR REPLACE VIEW v_alertas_activas AS
  SELECT a.id, a.telefono, a.direccion, a.estado, a.origen, a.creada_en,
         ST_Y(a.ubicacion::geometry) AS latitud,
         ST_X(a.ubicacion::geometry) AS longitud,
         a.incidencia_id, i.codigo AS incidencia_codigo
    FROM alertas a
    LEFT JOIN incidencias i ON i.id = a.incidencia_id
   WHERE a.estado = 'ACTIVA';