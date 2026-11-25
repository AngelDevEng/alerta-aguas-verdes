-- =====================================================================
-- Alerta Aguas Verdes - Flujo SOS: aceptacion, seguimiento y tracking
-- Fase 1 (correcciones 1-7)
--
-- TRANSACCIONAL. Revisar este archivo completo antes de aplicarlo en
-- produccion (Supabase). Idempotente donde es posible: se puede volver a
-- ejecutar sin duplicar columnas ni tablas.
--
-- No tocar incidencias.estado: es un ENUM (01_schema.sql:9) y ya arranca
-- en REGISTRADA.
-- =====================================================================

BEGIN;

-- ---------- 1. Ampliar el CHECK de alertas.estado ----------
-- `estado` ya es VARCHAR(15) (04_auth_alertas.sql:42) y los seis estados
-- caben (el mas largo es CANCELADA, 9 caracteres). No se altera el tipo:
-- `v_alertas_activas` depende de la columna y PostgreSQL rechaza el ALTER
-- con "cannot alter type of a column used by a view or rule".
--
-- Se eliminan por nombre explicito ambos nombres posibles (el original sin
-- nombre que PostgreSQL llama alertas_estado_check, y chk_estado_alerta si
-- ya existiera de una ejecucion previa). Para confirmar el nombre real antes
-- de aplicar, ejecutar:
--   SELECT conname, pg_get_constraintdef(oid)
--     FROM pg_constraint
--    WHERE conrelid = 'alertas'::regclass AND contype = 'c';
--
ALTER TABLE alertas DROP CONSTRAINT IF EXISTS alertas_estado_check;
ALTER TABLE alertas DROP CONSTRAINT IF EXISTS chk_estado_alerta;

ALTER TABLE alertas
  ADD CONSTRAINT chk_estado_alerta
  CHECK (estado IN ('ACTIVA','ACEPTADA','ATENDIDA','CANCELADA','FALSA','EXPIRADA'));

-- ---------- 2. Columnas de aceptacion y seguimiento ----------
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS aceptada_por UUID REFERENCES usuarios(id) ON DELETE SET NULL;
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS aceptada_en  TIMESTAMPTZ;
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS unidad_id    UUID REFERENCES unidades_serenazgo(id) ON DELETE SET NULL;
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS dispositivo_id TEXT;
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS escalada_en  TIMESTAMPTZ;
-- Un DEFAULT no puede referenciar otra columna: ahora() + intervalo fijo.
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS expira_en   TIMESTAMPTZ
  DEFAULT (now() + interval '20 minutes');

-- Una alerta ACEPTADA siempre tiene sereno, momento y unidad.
-- LIMITACION ON DELETE SET NULL: unidad_id referencia unidades_serenazgo(id)
-- con ON DELETE SET NULL. Si se elimina una unidad que es unidad_id de una
-- alerta ACEPTADA, unidad_id queda NULL y chk_alerta_aceptada falla
-- (exige unidad_id NOT NULL cuando estado = 'ACEPTADA'). Por tanto, antes de
-- eliminar (baja logica o fisica) una unidad asignada a una alerta ACEPTADA,
-- la aplicacion debe primero liberar/cerrar esa alerta o reasignar otra unidad.
ALTER TABLE alertas DROP CONSTRAINT IF EXISTS chk_alerta_aceptada;
ALTER TABLE alertas
  ADD CONSTRAINT chk_alerta_aceptada
  CHECK (estado <> 'ACEPTADA'
         OR (aceptada_por IS NOT NULL AND aceptada_en IS NOT NULL AND unidad_id IS NOT NULL));

CREATE INDEX IF NOT EXISTS idx_alertas_dispositivo
  ON alertas (dispositivo_id, estado, creada_en DESC)
  WHERE dispositivo_id IS NOT NULL;

-- Una sola SOS viva por dispositivo, incluso con peticiones concurrentes.
-- El servicio reintenta como "devuelve la existente" si choca con este indice.
CREATE UNIQUE INDEX IF NOT EXISTS uq_alertas_dispositivo_activa
  ON alertas (dispositivo_id)
  WHERE dispositivo_id IS NOT NULL AND estado IN ('ACTIVA','ACEPTADA');

-- ---------- 3. Sesiones anonimas del ciudadano ----------
-- El token viaja en el cuerpo JSON de POST /alertas y se guarda solo su
-- SHA-256: una filtracion de la BD no permite autenticar seguimiento.
-- NOTA FASE 5: la columna ip guarda la direccion IP del cliente. Evaluar en
-- Fase 5 si se requiere retención limitada (p. ej. 30 dias) o almacenamiento
-- solo del hash (SHA-256) para cumplir con protección de datos personales.
CREATE TABLE IF NOT EXISTS sessions_anonimas (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alerta_id      UUID NOT NULL REFERENCES alertas(id) ON DELETE CASCADE,
  token_hash     CHAR(64) NOT NULL UNIQUE,
  dispositivo_id TEXT,
  ip             TEXT,
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expira_en      TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
  revocado       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sessions_anonimas_alerta
  ON sessions_anonimas (alerta_id);

-- ---------- 4. Ubicaciones del ciudadano ----------
-- Se guardan desde que pulsa SOS, pero no se comparten hasta que un sereno
-- acepta. Retencion 30 dias (limpieza en Fase 5); solo ADMIN las consulta.
CREATE TABLE IF NOT EXISTS ubicaciones_ciudadano (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alerta_id      UUID NOT NULL REFERENCES alertas(id) ON DELETE CASCADE,
  ubicacion      GEOGRAPHY(Point,4326) NOT NULL,
  velocidad_kmh  NUMERIC(5,1) CHECK (velocidad_kmh >= 0),
  registrado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ubicaciones_ciudadano_alerta
  ON ubicaciones_ciudadano (alerta_id, registrado_en DESC);

-- ---------- 5. RLS sin politicas (deny-all) ----------
-- El backend conecta como owner de Supabase (`postgres.<project-ref>` en
-- `DATABASE_URL`, ver backend/.env.example:24). El owner ignora RLS, por lo que
-- el flujo del backend sigue funcionando. Una conexion con rol limitado (p. ej.
-- `anon`, `authenticated` de Supabase) no puede leer estas tablas ni vistas por
-- accidente. RLS se activa solo sobre tablas cuyo dueño es current_user.
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT schemaname, tablename, tableowner
          FROM pg_tables
         WHERE schemaname = 'public'
    LOOP
        IF r.tableowner = current_user THEN
            EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.schemaname, r.tablename);
            RAISE NOTICE 'RLS activada en %.%', r.schemaname, r.tablename;
        ELSE
            RAISE NOTICE 'RLS omitida en %.% (dueno: %)', r.schemaname, r.tablename, r.tableowner;
        END IF;
    END LOOP;
END $$;

-- Revocar acceso directo a tablas y secuencias para los roles publicos de Supabase.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

-- Revocar acceso directo a vistas solo si existen (proteccion contra esquema
-- incompleto). v_alertas_activas (04_auth_alertas.sql:56) y
-- v_incidencias_geojson (02_indices_triggers.sql:71).
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT count(*) INTO v_count
      FROM pg_views
     WHERE schemaname = 'public' AND viewname = 'v_alertas_activas';
    IF v_count > 0 THEN
        EXECUTE 'REVOKE ALL ON v_alertas_activas FROM PUBLIC';
        RAISE NOTICE 'REVOKE aplicado en v_alertas_activas';
    ELSE
        RAISE NOTICE 'v_alertas_activas no existe; REVOKE omitido';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_views
     WHERE schemaname = 'public' AND viewname = 'v_incidencias_geojson';
    IF v_count > 0 THEN
        EXECUTE 'REVOKE ALL ON v_incidencias_geojson FROM PUBLIC';
        RAISE NOTICE 'REVOKE aplicado en v_incidencias_geojson';
    ELSE
        RAISE NOTICE 'v_incidencias_geojson no existe; REVOKE omitido';
    END IF;
END $$;

-- Revocar EXECUTE sobre funciones propias de public (dueño = current_user y no
-- pertenecientes a una extension). Se usa pg_proc para evitar firmas escritas
-- a mano; se revoca de PUBLIC, anon y authenticated.
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT n.nspname,
               p.proname,
               pg_get_function_identity_arguments(p.oid) AS args
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proowner::regrole = current_user::regrole
           AND NOT EXISTS (
               SELECT 1
                 FROM pg_depend d
                 JOIN pg_extension e ON d.objid = e.oid
                WHERE d.refobjid = p.oid
           )
    LOOP
        EXECUTE format(
            'REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC',
            r.nspname, r.proname, r.args
        );
        RAISE NOTICE 'REVOKE EXECUTE aplicado en %.%()', r.nspname, r.proname;
    END LOOP;
END $$;

-- Privilegios por defecto para objetos futuros creados en el esquema public.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;

-- Nota: la seccion RLS y permisos de este archivo se complementa y corrige en
-- database/08_cerrar_acceso_publico.sql, que revoca acceso a vistas y secuencias
-- y aplica ALTER DEFAULT PRIVILEGES tambien a funciones. Aplicar 08 despues de 07.

COMMIT;

-- =====================================================================
-- Verificacion posterior (ejecutar DESPUES de COMMIT, fuera de la transaccion)
-- =====================================================================

-- 6a. RLS activada en todas las tablas publicas (debe ser true en todas).
SELECT tablename, tableowner, rowsecurity
  FROM pg_tables
 WHERE schemaname = 'public'
 ORDER BY tablename;

-- 6b. Grants residuales de anon y authenticated (debe devolver 0 filas).
SELECT grantee, table_name, privilege_type
  FROM information_schema.table_privileges
 WHERE table_schema = 'public'
   AND grantee IN ('anon', 'authenticated')
 ORDER BY grantee, table_name, privilege_type;

