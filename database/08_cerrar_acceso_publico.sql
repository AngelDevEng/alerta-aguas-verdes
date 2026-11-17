-- =====================================================================
-- Alerta Aguas Verdes - Cerrar acceso público a tablas y vistas
--
-- Aplica DESPUES de 07_sos_seguimiento.sql. Revooca todo acceso directo
-- de los roles publicos de Supabase (anon, authenticated) sobre tablas,
-- vistas y secuencias del esquema public, y revoca EXECUTE sobre funciones
-- propias. El backend conecta como owner de Supabase y ignora RLS; los
-- roles publicos quedan bloqueados para lecturas accidentales a traves de
-- la API REST de Supabase con la clave anon.
--
-- TRANSACCIONAL. Idempotente donde es posible.
-- =====================================================================

BEGIN;

-- ---------- Revocar acceso a tablas ----------
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- ---------- Revocar acceso a secuencias ----------
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

-- ---------- Revocar acceso a vistas ----------
REVOKE ALL ON v_alertas_activas FROM anon, authenticated;
REVOKE ALL ON v_incidencias_geojson FROM anon, authenticated;

-- ---------- Revocar EXECUTE en funciones propias de public (no extensiones) ----------
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
           AND p.proowner = current_user
           AND NOT EXISTS (
               SELECT 1
                 FROM pg_depend d
                 JOIN pg_extension e ON d.objid = e.oid
                WHERE d.refobjid = p.oid
           )
    LOOP
        EXECUTE format(
            'REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated',
            r.nspname, r.proname, r.args
        );
        RAISE NOTICE 'REVOKE EXECUTE aplicado en %.%()', r.nspname, r.proname;
    END LOOP;
END $$;

-- ---------- Privilegios por defecto para objetos futuros ----------
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;

COMMIT;

-- =====================================================================
-- Verificacion posterior (ejecutar fuera de la transaccion)
-- =====================================================================

-- Grants residuales de anon y authenticated (debe devolver 0 filas).
SELECT grantee, table_name, privilege_type
  FROM information_schema.table_privileges
 WHERE table_schema = 'public'
   AND grantee IN ('anon', 'authenticated')
 ORDER BY grantee, table_name, privilege_type;

-- RLS activada en todas las tablas publicas.
SELECT tablename, tableowner, rowsecurity
  FROM pg_tables
 WHERE schemaname = 'public'
 ORDER BY tablename;