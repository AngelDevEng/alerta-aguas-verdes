-- =====================================================================
-- Migracion 06: baja logica de unidades de serenazgo
--
-- Idempotente: ejecutable mas de una vez sin efecto adicional. El objetivo
-- es no perder el historial de la unidad (ubicaciones, incidencias,
-- historial_incidencia) cuando se da de baja, en vez de un DELETE fisico
-- que dejaria esos FK en SET NULL.
-- =====================================================================

ALTER TABLE unidades_serenazgo
  ADD COLUMN IF NOT EXISTS eliminado_en TIMESTAMPTZ;

COMMENT ON COLUMN unidades_serenazgo.eliminado_en IS
  'Marca de baja logica; NULL = unidad activa. Los listados excluyen filas con marca.';

-- Indice parcial para que los listados "activos" no barran las bajas.
CREATE INDEX IF NOT EXISTS idx_unidades_eliminado_en
  ON unidades_serenazgo (eliminado_en)
  WHERE eliminado_en IS NULL;
