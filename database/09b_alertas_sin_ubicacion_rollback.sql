-- =====================================================================
-- 09b (rollback): revierte alertas.sin_ubicacion y la vista v_alertas_activas
-- al estado anterior a la migracion 09b.
--
-- La columna se elimina (era NOT NULL DEFAULT false, sin datos que migrar
-- porque las alertas existentes quedaron en false). La vista vuelve a su
-- definicion original (sin sin_ubicacion ni el CASE de direccion).
-- =====================================================================

DROP INDEX IF EXISTS idx_alertas_sin_ubicacion;

ALTER TABLE alertas DROP COLUMN IF EXISTS sin_ubicacion;

CREATE OR REPLACE VIEW v_alertas_activas AS
  SELECT a.id, a.telefono, a.direccion, a.estado, a.origen, a.creada_en,
         ST_Y(a.ubicacion::geometry) AS latitud,
         ST_X(a.ubicacion::geometry) AS longitud,
         a.incidencia_id, i.codigo AS incidencia_codigo
    FROM alertas a
    LEFT JOIN incidencias i ON i.id = a.incidencia_id
   WHERE a.estado = 'ACTIVA';