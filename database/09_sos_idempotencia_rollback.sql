-- =====================================================================
-- Rollback de 09_sos_idempotencia.sql
--
-- Elimina la tabla de idempotencia y su funcion de limpieza. La tabla se
-- recrea sin problema al reejecutar 09_sos_idempotencia.sql.
-- =====================================================================

BEGIN;

DROP TABLE IF EXISTS alertas_idempotencia;
DROP FUNCTION IF EXISTS fn_limpiar_idempotencia();

COMMIT;