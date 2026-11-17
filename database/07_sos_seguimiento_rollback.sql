-- =====================================================================
-- Alerta Aguas Verdes - Rollback de Fase 1 (07_sos_seguimiento.sql)
--
-- REVERSA DE LA MIGRACION 07. ADVERTENCIA DE PERDIDA DE DATOS:
--   * DROP TABLE sessions_anonimas y ubicaciones_ciudadano BORRA TODOS LOS
--     DATOS de esas tablas (sesiones anonimas, ubicaciones del ciudadano).
--   * DROP COLUMN en alertas BORRA los valores de aceptada_por, aceptada_en,
--     unidad_id, dispositivo_id, escalada_en, expira_en para todas las filas.
--   * No hay forma de recuperar esos datos sin un respaldo previo.
--
-- Requisitos previos:
--   1. Reemplazar <DEFINICION_ORIGINAL> por el pg_get_constraintdef(oid)
--      obtenido de pg_constraint ANTES de aplicar 07_sos_seguimiento.sql.
--   2. Ejecutar como el rol owner de la base de datos (postgres.<project-ref>).
-- =====================================================================

BEGIN;

-- ---------- 0. Abortar si el placeholder <DEFINICION_ORIGINAL> no fue reemplazado ----------
DO $$
DECLARE
    placeholder text := '<DEFINICION_ORIGINAL>';
BEGIN
    IF placeholder = '<DEFINICION_ORIGINAL>' THEN
        RAISE EXCEPTION
            'ERROR DE ROLLBACK: El placeholder <DEFINICION_ORIGINAL> no fue reemplazado. '
            'Obtén la definicion original con: '
            'SELECT pg_get_constraintdef(oid) FROM pg_constraint '
            "WHERE conrelid = 'alertas'::regclass AND contype = 'c' AND conname = 'chk_estado_alerta'; "
            'y sustitui el placeholder en este archivo antes de ejecutarlo.';
    END IF;
END $$;

-- ---------- 1. Manejo de filas con estados nuevos ----------
-- Los estados ACEPTADA y EXPIRADA no existen en el CHECK original.
-- Opcion A (seleccionada): convertirlos para preservar las filas.
--   ACEPTADA -> ACTIVA   (la alerta vuelve a estar abierta)
--   EXPIRADA -> CANCELADA (la alerta se cierra como cancelada)
--
-- Opcion B (alternativa): abortar si existen filas con estos estados.
--   Si prefieres abortar en vez de convertir, reemplaza los dos UPDATE
--   siguientes por:
--     DO $$
--     BEGIN
--       IF EXISTS (SELECT 1 FROM alertas WHERE estado IN ('ACEPTADA','EXPIRADA')) THEN
--         RAISE EXCEPTION 'Existen alertas con estados nuevos (ACEPTADA/EXPIRADA). Abortando rollback.';
--       END IF;
--     END $$;
UPDATE alertas SET estado = 'ACTIVA' WHERE estado = 'ACEPTADA';
UPDATE alertas SET estado = 'CANCELADA' WHERE estado = 'EXPIRADA';

-- ---------- 2. Revertir restricciones de alertas ----------
ALTER TABLE alertas DROP CONSTRAINT IF EXISTS chk_alerta_aceptada;
ALTER TABLE alertas DROP CONSTRAINT IF EXISTS chk_estado_alerta;

-- ---------- 3. Restaurar CHECK original de alertas.estado ----------
-- REEMPLAZAR '<DEFINICION_ORIGINAL>' por el pg_get_constraintdef(oid) obtenido
-- de pg_constraint ANTES de aplicar 07_sos_seguimiento.sql.
-- Ejemplo (ajustar segun lo que devuelva tu base):
--   CHECK (estado IN ('ACTIVA','ATENDIDA','CANCELADA','FALSA'));
ALTER TABLE alertas ADD CONSTRAINT alertas_estado_check
  CHECK (<DEFINICION_ORIGINAL>);

-- ---------- 4. Quitar columnas nuevas de alertas ----------
-- PERDIDA DE DATOS: los valores de estas columnas en todas las filas se borran.
ALTER TABLE alertas DROP COLUMN IF EXISTS aceptada_por;
ALTER TABLE alertas DROP COLUMN IF EXISTS aceptada_en;
ALTER TABLE alertas DROP COLUMN IF EXISTS unidad_id;
ALTER TABLE alertas DROP COLUMN IF EXISTS dispositivo_id;
ALTER TABLE alertas DROP COLUMN IF EXISTS escalada_en;
ALTER TABLE alertas DROP COLUMN IF EXISTS expira_en;

-- ---------- 5. Eliminar tablas nuevas ----------
-- PERDIDA DE DATOS: todas las filas de sessions_anonimas y ubicaciones_ciudadano se borran.
DROP TABLE IF EXISTS ubicaciones_ciudadano;
DROP TABLE IF EXISTS sessions_anonimas;

COMMIT;