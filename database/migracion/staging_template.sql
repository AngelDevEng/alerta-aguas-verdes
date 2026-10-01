-- PLANTILLA: adaptar columnas a la BD real de XAMPP
CREATE TABLE legacy_incidencias (
  id TEXT, tipo TEXT, descripcion TEXT, latitud TEXT, longitud TEXT,
  estado TEXT, fecha TEXT
);

INSERT INTO incidencias (tipo_id, descripcion, estado, ubicacion, ocurrido_en)
SELECT
  COALESCE((SELECT id FROM tipos_incidencia t WHERE upper(t.nombre) LIKE '%'||upper(l.tipo)||'%' LIMIT 1),
           (SELECT id FROM tipos_incidencia WHERE codigo='SOSP')),
  l.descripcion,
  CASE upper(l.estado) WHEN 'ATENDIDO' THEN 'ATENDIDA'::estado_incidencia
                       WHEN 'PENDIENTE' THEN 'REGISTRADA'::estado_incidencia
                       ELSE 'REGISTRADA'::estado_incidencia END,
  ST_SetSRID(ST_MakePoint(l.longitud::float8, l.latitud::float8),4326)::geography,
  l.fecha::timestamptz
FROM legacy_incidencias l
WHERE l.latitud ~ '^-?[0-9.]+$' AND l.longitud ~ '^-?[0-9.]+$';   -- descarta coordenadas inválidas
