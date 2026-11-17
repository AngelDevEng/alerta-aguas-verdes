-- =====================================================================
-- Limpieza de datos de prueba Fase 1 (alertas con dispositivo_id LIKE 'test-%')
--
-- Identifica filas por alertas.dispositivo_id LIKE 'test-%', guarda los
-- IDs de las incidencias de prueba en una tabla temporal ANTES de borrar
-- las alertas, ejecuta una version de ensayo con ROLLBACK, y aborta si
-- el conteo de filas borradas no coincide.
--
-- NO usar DELETE basado en referencia/fecha.
--
-- Cascade en cascada (según FK reales de database/*.sql):
--   alertas.dispositivo_id (test-%) -> sessions_anonimas.alerta_id      ON DELETE CASCADE
--   alertas.dispositivo_id (test-%) -> ubicaciones_ciudadano.alerta_id  ON DELETE CASCADE
--   incidencias.id (asociadas)      -> historial_incidencia.incidencia_id ON DELETE CASCADE
--   incidencias.id (asociadas)      -> evidencias_multimedia.incidencia_id ON DELETE CASCADE
--
-- Tablas afectadas por la limpieza:
--   sessions_anonimas, ubicaciones_ciudadano, alertas, historial_incidencia,
--   evidencias_multimedia, incidencias
-- =====================================================================

-- =====================================================================
-- PASO 0: SELECT previo (identificar lo que se va a borrar)
-- Guarda los IDs de incidencias ANTES de borrar las alertas.
-- =====================================================================

CREATE TEMP TABLE _test_alertas AS
  SELECT id AS alerta_id, incidencia_id, dispositivo_id, estado, creada_en
    FROM alertas
   WHERE dispositivo_id LIKE 'test-%';

CREATE TEMP TABLE _test_incidencias AS
  SELECT DISTINCT i.id AS incidencia_id, i.referencia, i.creado_en
    FROM _test_alertas a
    JOIN incidencias i ON i.id = a.incidencia_id
   WHERE a.incidencia_id IS NOT NULL;

SELECT '--- ALERTAS DE PRUEBA ENCONTRADAS ---' AS paso;
SELECT * FROM _test_alertas ORDER BY creada_en DESC;

SELECT '--- INCIDENCIAS DE PRUEBA ENCONTRADAS ---' AS paso;
SELECT * FROM _test_incidencias ORDER BY creado_en DESC;

SELECT 'alertas de prueba encontradas' AS paso, count(*) AS total FROM _test_alertas;
SELECT 'incidencias de prueba encontradas' AS paso, count(*) AS total FROM _test_incidencias;

-- =====================================================================
-- PASO 1: VERSION DE ENSAYO CON ROLLBACK (ejecutar primero para validar)
-- =====================================================================

BEGIN;

DELETE FROM sessions_anonimas WHERE alerta_id IN (SELECT alerta_id FROM _test_alertas);
DELETE FROM ubicaciones_ciudadano WHERE alerta_id IN (SELECT alerta_id FROM _test_alertas);
DELETE FROM historial_incidencia WHERE incidencia_id IN (SELECT incidencia_id FROM _test_incidencias);
DELETE FROM evidencias_multimedia WHERE incidencia_id IN (SELECT incidencia_id FROM _test_incidencias);
DELETE FROM alertas WHERE dispositivo_id LIKE 'test-%';
DELETE FROM incidencias WHERE id IN (SELECT incidencia_id FROM _test_incidencias);

-- Conteo esperado segun el SELECT previo
SELECT 'borrado en ensayo - alertas' AS paso, count(*) AS total FROM _test_alertas;
SELECT 'borrado en ensayo - incidencias' AS paso, count(*) AS total FROM _test_incidencias;

-- Verificar que no quede nada
SELECT 'alertas restantes tras ensayo' AS paso, count(*) AS total
  FROM alertas WHERE dispositivo_id LIKE 'test-%';

ROLLBACK;  -- Deshace el borrado de ensayo; solo validamos que funcionaria

-- =====================================================================
-- PASO 2: EJECUCION REAL CON ABORT SI EL CONTEO NO COINCIDE
-- =====================================================================

DO $$
DECLARE
  v_alertas     int;
  v_incidencias int;
BEGIN
  SELECT count(*) INTO v_alertas FROM _test_alertas;
  SELECT count(*) INTO v_incidencias FROM _test_incidencias;

  IF v_alertas = 0 AND v_incidencias = 0 THEN
    RAISE NOTICE 'No hay datos de prueba que limpiar.';
  END IF;
END $$;

BEGIN;

DELETE FROM sessions_anonimas WHERE alerta_id IN (SELECT alerta_id FROM _test_alertas);
DELETE FROM ubicaciones_ciudadano WHERE alerta_id IN (SELECT alerta_id FROM _test_alertas);
DELETE FROM historial_incidencia WHERE incidencia_id IN (SELECT incidencia_id FROM _test_incidencias);
DELETE FROM evidencias_multimedia WHERE incidencia_id IN (SELECT incidencia_id FROM _test_incidencias);
DELETE FROM alertas WHERE dispositivo_id LIKE 'test-%';
DELETE FROM incidencias WHERE id IN (SELECT incidencia_id FROM _test_incidencias);

-- Abort si el conteo de alertas borradas no coincide con el SELECT previo
DO $$
DECLARE
  v_antes int;
  v_despues int;
BEGIN
  SELECT count(*) INTO v_antes FROM _test_alertas;
  SELECT count(*) INTO v_despues FROM alertas WHERE dispositivo_id LIKE 'test-%';

  IF v_despues <> 0 THEN
    RAISE EXCEPTION
      'ABORTO DE LIMPIEZA: Quedan % alertas con dispositivo_id LIKE ''test-%''. '
      'Se esperaban 0 tras borrar % alertas.',
      v_despues, v_antes;
  END IF;
END $$;

-- =====================================================================
-- PASO 3: VERIFICACION FINAL
-- =====================================================================

SELECT 'alertas restantes con test-%' AS paso, count(*) AS total
  FROM alertas WHERE dispositivo_id LIKE 'test-%';

SELECT 'sessions_anonimas restantes de prueba' AS paso, count(*) AS total
  FROM sessions_anonimas sa
  JOIN alertas a ON a.id = sa.alerta_id
 WHERE a.dispositivo_id LIKE 'test-%';

SELECT 'ubicaciones_ciudadano restantes de prueba' AS paso, count(*) AS total
  FROM ubicaciones_ciudadano uc
  JOIN alertas a ON a.id = uc.alerta_id
 WHERE a.dispositivo_id LIKE 'test-%';

SELECT 'historial_incidencia restante de prueba' AS paso, count(*) AS total
  FROM historial_incidencia hi
  JOIN incidencias i ON i.id = hi.incidencia_id
  JOIN alertas a ON a.incidencia_id = i.id
 WHERE a.dispositivo_id LIKE 'test-%';

SELECT 'evidencias_multimedia restante de prueba' AS paso, count(*) AS total
  FROM evidencias_multimedia em
  JOIN incidencias i ON i.id = em.incidencia_id
  JOIN alertas a ON a.incidencia_id = i.id
 WHERE a.dispositivo_id LIKE 'test-%';

DROP TABLE IF EXISTS _test_alertas;
DROP TABLE IF EXISTS _test_incidencias;

COMMIT;