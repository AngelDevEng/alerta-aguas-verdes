-- =====================================================================
-- Alerta Aguas Verdes - Idempotencia del SOS (Fase 0)
--
-- TRANSACCIONAL e idempotente: se puede volver a ejecutar sin duplicar
-- objetos. Ejecutar DESPUES de 08 (que ya revoca acceso a anon/authenticated
-- sobre tablas y aplica ALTER DEFAULT PRIVILEGES).
--
-- Problema que resuelve: al reintentar `POST /alertas` (mala señal, timeout,
-- reanudar la app) el cliente puede crear alertas CRITICAS duplicadas. Una
-- `Idempotency-Key` estable permite que el reintento devuelva la MISMA alerta
-- en vez de crear otra.
--
-- `clave_hash` es el SHA-256 de la clave que envia el cliente: la clave en
-- claro nunca se guarda. `solicitud_hash` es el SHA-256 del cuerpo canonico,
-- para detectar una clave reutilizada con otro contenido.
-- =====================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS alertas_idempotencia (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave_hash     CHAR(64) NOT NULL UNIQUE,
  solicitud_hash CHAR(64) NOT NULL,
  alerta_id      UUID NOT NULL REFERENCES alertas(id) ON DELETE CASCADE,
  dispositivo_id TEXT,
  creada_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expira_en      TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_alertas_idempotencia_alerta
  ON alertas_idempotencia (alerta_id);

CREATE INDEX IF NOT EXISTS idx_alertas_idempotencia_expira
  ON alertas_idempotencia (expira_en);

-- El backend conecta como owner de Supabase (`postgres.<project-ref>`), que
-- ignora RLS. Se activa igual para que un rol limitado (anon/authenticated)
-- no pueda leer ni escribir estas claves por accidente.
ALTER TABLE alertas_idempotencia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON alertas_idempotencia FROM anon, authenticated;

-- Limpieza periodica de claves vencidas. Se invoca desde el servicio al crear
-- una alerta; devuelve void para poder llamarla sin leer resultado.
CREATE OR REPLACE FUNCTION fn_limpiar_idempotencia() RETURNS void
LANGUAGE sql
AS $$
  DELETE FROM alertas_idempotencia WHERE expira_en < now();
$$;

REVOKE EXECUTE ON FUNCTION fn_limpiar_idempotencia() FROM PUBLIC, anon, authenticated;

COMMIT;

-- =====================================================================
-- Verificacion posterior (ejecutar DESPUES de COMMIT, fuera de la transaccion)
-- =====================================================================

-- La tabla existe y RLS esta activa.
SELECT tablename, rowsecurity
  FROM pg_tables
 WHERE schemaname = 'public' AND tablename = 'alertas_idempotencia';

-- Sin privilegios residuales de anon/authenticated sobre la tabla nueva.
SELECT grantee, privilege_type
  FROM information_schema.table_privileges
 WHERE table_schema = 'public'
   AND table_name = 'alertas_idempotencia'
   AND grantee IN ('anon', 'authenticated');