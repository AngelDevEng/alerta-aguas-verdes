-- =====================================================================
-- 09b: alertas sin ubicacion
-- Ejecutar DESPUES de 09_sos_idempotencia.sql. Idempotente donde es posible.
--
-- Una SOS puede crearse sin coordenadas cuando el GPS del dispositivo falla.
-- Hasta ahora la alerta se guardaba igual (con lat/lng 0,0), lo que ensuciaba
-- el mapa de calor y hacia que la unidad acudiera a un punto falso en el
-- oceano. Esta migracion marca explicitamente esas alertas y las excluye de:
--   - el mapa de calor (incidencias sin ubicacion fiable),
--   - fn_unidades_cercanas (no se despacha a un punto sin ubicacion),
--   - la vista v_alertas_activas (el panel de central ve "Sin ubicacion:
--     llamar al ciudadano").
-- =====================================================================

-- ---------- Columna ----------
ALTER TABLE alertas
  ADD COLUMN IF NOT EXISTS sin_ubicacion BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN alertas.sin_ubicacion IS
  'True cuando el dispositivo no pudo obtener ubicacion al crear la SOS. '
  'La alerta existe igual; el operador debe contactar al ciudadano por telefono.';

-- ---------- Vista de alertas vivas ----------
-- Expone sin_ubicacion y marca la direccion como "Sin ubicacion" cuando
-- corresponde, para que el panel de central muestre el aviso correcto.
-- DROP+CREATE (no OR REPLACE) porque cambia el orden de columnas.
DROP VIEW IF EXISTS v_alertas_activas;
CREATE VIEW v_alertas_activas AS
  SELECT a.id,
         a.telefono,
         (CASE WHEN a.sin_ubicacion THEN 'Sin ubicación: llamar al ciudadano'
              ELSE a.direccion
         END)::varchar(200) AS direccion,
         a.estado,
         a.origen,
         a.creada_en,
         a.sin_ubicacion AS "sinUbicacion",
         ST_Y(a.ubicacion::geometry) AS latitud,
         ST_X(a.ubicacion::geometry) AS longitud,
         a.incidencia_id,
         i.codigo AS incidencia_codigo
    FROM alertas a
    LEFT JOIN incidencias i ON i.id = a.incidencia_id
   WHERE a.estado = 'ACTIVA';

-- ---------- Funcion: unidades cercanas ----------
-- Las alertas sin ubicacion no se despachan a un punto: se excluyen de la
-- busqueda de unidades cercanas (no tiene sentido acercar una unidad a 0,0).
-- La funcion ya filtra unidades DISPONIBLE con ultima_ubicacion; aqui solo se
-- documenta que el SOS sin ubicacion no entra por esta via (el operador llama).
-- No se altera la funcion: el filtro lo aplica el servicio al decidir si
-- despacha (ver alertas.service.ts / incidencias.service.ts).

-- ---------- Mapa de calor ----------
-- Las incidencias de un SOS sin ubicacion se crean en (0,0) (lat/lng del DTO).
-- El mapa de calor agrupa por celda metrica sobre la ubicacion; para no pintar
-- un punto falso en el golfo, se excluyen las incidencias cuyo origen sea un
-- SOS sin ubicacion. La condicion se aplica en la consulta (incidencias.service
-- .ts zonasCalor/estadisticas) porque `incidencias` no tiene esa marca; se
-- usa el join a `alertas` via `incidencia_id`.
--
-- Para que el filtro sea barato, se indexa la columna nueva:
CREATE INDEX IF NOT EXISTS idx_alertas_sin_ubicacion
  ON alertas (sin_ubicacion) WHERE sin_ubicacion = true;

-- ---------- Verificacion ----------
-- Alerta sin ubicacion visible en la vista con el aviso:
--   SELECT id, direccion, "sinUbicacion" FROM v_alertas_activas;
-- Conteo de alertas sin ubicacion:
--   SELECT count(*) FROM alertas WHERE sin_ubicacion = true;
