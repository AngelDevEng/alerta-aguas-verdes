-- =====================================================================
-- PLANTILLA de migracion XAMPP (MySQL/MariaDB) -> PostgreSQL/Supabase
-- =====================================================================
-- NO EJECUTAR contra produccion sin respaldo. Este archivo no corre solo:
--   1) crear las tablas legacy_* (seccion 0),
--   2) importar los CSV exportados de phpMyAdmin (seccion 1),
--   3) correr las transformaciones (seccion 2),
--   4) validar con database/migracion/99_conteos_origen_destino.sql.
--
-- Convencion: las tablas legacy_* replican las columnas MySQL como TEXT
-- para que la importacion de CSV no falle por tipos; la validacion
-- (coordenadas, DNI) y el casteo se hacen en la transformacion.
--
-- Nombres de las tablas legacy (MySQL `serenazgo_test`, ver docs/INFORME):
--   incidentes, serenazgo, central, alertas, zonas, dispositivos, patrulleros.
-- Aqui se migran incidentes, serenazgo y central (los que mapean al modelo).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) Tablas staging (espejo del legacy, todo TEXT)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS legacy_incidentes, legacy_serenazgo, legacy_central CASCADE;

CREATE TABLE legacy_incidentes (
  id              TEXT,
  tipo            TEXT,
  descripcion     TEXT,
  latitud         TEXT,
  longitud        TEXT,
  direccion       TEXT,
  nivel_urgencia  TEXT,
  estado          TEXT,
  reportado_por   TEXT,
  fecha_incidente TEXT
);

CREATE TABLE legacy_serenazgo (
  codigo               TEXT,
  placa                TEXT,
  nombre               TEXT,
  dni                  TEXT,
  password_hash        TEXT,
  numero               TEXT,
  licencia             TEXT,
  imagen               TEXT,
  zona_id              TEXT,
  latitud              TEXT,
  longitud             TEXT,
  ultima_actualizacion TEXT
);

CREATE TABLE legacy_central (
  id       TEXT,
  nombre   TEXT,
  telefono TEXT
);

-- ---------------------------------------------------------------------
-- 1) Importar CSV (ejecutar una vez por tabla; psql o Table Editor)
-- ---------------------------------------------------------------------
--  \copy legacy_incidentes FROM 'incidentes.csv' CSV HEADER
--  \copy legacy_serenazgo  FROM 'serenazgo.csv'  CSV HEADER
--  \copy legacy_central    FROM 'central.csv'    CSV HEADER

-- ---------------------------------------------------------------------
-- 2) Transformaciones
-- ---------------------------------------------------------------------

-- 2.a incidentes -> incidencias
--     estado:         pendiente -> REGISTRADA, en_proceso -> EN_ATENCION,
--                     resuelto -> ATENDIDA
--     nivel_urgencia: bajo -> BAJA, medio -> MEDIA, alto -> ALTA
--     tipo:           empareja por nombre; si no hay match, cae a SOSP.
--     reportado_por INT del legacy NO mapea a UUID: queda NULL.
INSERT INTO incidencias (tipo_id, descripcion, estado, prioridad, ubicacion, referencia, ocurrido_en)
SELECT
  COALESCE((SELECT id FROM tipos_incidencia t WHERE upper(t.nombre) LIKE '%' || upper(l.tipo) || '%' LIMIT 1),
           (SELECT id FROM tipos_incidencia WHERE codigo = 'SOSP')),
  l.descripcion,
  CASE upper(l.estado) WHEN 'RESUELTO'   THEN 'ATENDIDA'::estado_incidencia
                       WHEN 'EN_PROCESO' THEN 'EN_ATENCION'::estado_incidencia
                       ELSE 'REGISTRADA'::estado_incidencia END,
  CASE upper(l.nivel_urgencia) WHEN 'ALTO' THEN 'ALTA'::prioridad_nivel
                               WHEN 'BAJO' THEN 'BAJA'::prioridad_nivel
                               ELSE 'MEDIA'::prioridad_nivel END,
  ST_SetSRID(ST_MakePoint(l.longitud::float8, l.latitud::float8), 4326)::geography,
  l.direccion,
  COALESCE(NULLIF(l.fecha_incidente, '')::timestamptz, now())
FROM legacy_incidentes l
WHERE l.latitud  ~ '^-?[0-9.]+$'
  AND l.longitud ~ '^-?[0-9.]+$';   -- descarta coordenadas invalidas

-- 2.b serenazgo -> usuarios (rol SERENO)
--     email: el legacy no lo tiene; se sintetiza <dni>@serenazgo.local.
--     password_hash: si viene un bcrypt valido se conserva; si no, se deja
--     un hash INUTILIZABLE (nadie entra hasta asignar clave real).
INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id, telefono)
SELECT
  l.dni,
  COALESCE(NULLIF(split_part(trim(l.nombre), ' ', 1), ''), 'Sereno'),
  NULLIF(trim(substr(trim(l.nombre), length(split_part(trim(l.nombre), ' ', 1)) + 1)), '') ,
  lower(l.dni) || '@serenazgo.local',
  CASE WHEN l.password_hash LIKE '$2%'
       THEN l.password_hash
       ELSE '$2a$12$EHidfmMr68yo/wRkc9HQfezu8Or5OvFzdPEuCK8kk9BpmJSF99ry2' END,
  (SELECT id FROM roles WHERE nombre = 'SERENO'),
  l.numero
FROM legacy_serenazgo l
WHERE l.dni ~ '^[0-9]{8}$'
ON CONFLICT (dni) DO NOTHING;

-- 2.c serenazgo -> unidades_serenazgo (responsable = usuario recien creado)
--     tipo: el legacy no distingue; se asume PATRULLA.
INSERT INTO unidades_serenazgo (codigo, tipo, placa, responsable_id, ultima_ubicacion, ultima_actualizacion)
SELECT
  COALESCE(NULLIF(trim(l.codigo), ''), 'SER-' || l.dni),
  'PATRULLA'::tipo_unidad,
  NULLIF(trim(l.placa), ''),
  u.id,
  CASE WHEN l.latitud ~ '^-?[0-9.]+$' AND l.longitud ~ '^-?[0-9.]+$'
       THEN ST_SetSRID(ST_MakePoint(l.longitud::float8, l.latitud::float8), 4326)::geography END,
  NULLIF(l.ultima_actualizacion, '')::timestamptz
FROM legacy_serenazgo l
JOIN usuarios u ON u.dni = l.dni
WHERE l.dni ~ '^[0-9]{8}$'
ON CONFLICT (codigo) DO NOTHING;

-- 2.d central -> contactos_emergencia
--     Choca con la semilla de 05_catalogos_app.sql: ON CONFLICT evita
--     duplicar por (nombre, activo); usar DO UPDATE si el telefono del
--     legacy debe imponerse.
INSERT INTO contactos_emergencia (nombre, telefono, orden, activo)
SELECT
  l.nombre,
  l.telefono,
  (row_number() OVER (ORDER BY l.id))::smallint,
  TRUE
FROM legacy_central l
WHERE NULLIF(trim(l.nombre), '') IS NOT NULL
  AND NULLIF(trim(l.telefono), '') IS NOT NULL
ON CONFLICT (nombre, activo) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3) Validar: ejecutar database/migracion/99_conteos_origen_destino.sql
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 4) Limpiar staging cuando este validado (descomentar)
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS legacy_incidentes, legacy_serenazgo, legacy_central CASCADE;
