-- =====================================================================
-- Conteos ORIGEN (staging legacy_) vs DESTINO (modelo nuevo)
-- Ejecutar en Supabase (SQL Editor) DESPUES de las transformaciones de
-- staging_template.sql. Es la evidencia de paridad de conteos del informe.
-- =====================================================================
-- Notas:
--   * incidencias / contactos_emergencia incluyen filas de 03_seed.sql y
--     05_catalogos_app.sql, por eso el destino puede superar al origen.
--     La columna `diferencia` = destino - origen lo hace explicito.
--   * los usuarios migrados se aíslan con el email sintetico @serenazgo.local.

WITH
inc_o AS (SELECT count(*) n FROM legacy_incidentes
           WHERE latitud ~ '^-?[0-9.]+$' AND longitud ~ '^-?[0-9.]+$'),
ser_o AS (SELECT count(*) n FROM legacy_serenazgo WHERE dni ~ '^[0-9]{8}$'),
cen_o AS (SELECT count(*) n FROM legacy_central
           WHERE NULLIF(trim(nombre), '') IS NOT NULL
             AND NULLIF(trim(telefono), '') IS NOT NULL),
inc_d AS (SELECT count(*) n FROM incidencias),
usr_d AS (SELECT count(*) n FROM usuarios WHERE email LIKE '%@serenazgo.local'),
uni_d AS (SELECT count(*) n FROM unidades_serenazgo u
            JOIN usuarios us ON us.id = u.responsable_id
           WHERE us.email LIKE '%@serenazgo.local'),
cen_d AS (SELECT count(*) n FROM contactos_emergencia)
SELECT 'incidentes -> incidencias'          AS flujo,
       inc_o.n                              AS origen,
       inc_d.n                              AS destino,
       (inc_d.n - inc_o.n)                  AS diferencia,
       'destino incluye 03_seed.sql'        AS nota
  FROM inc_o, inc_d
UNION ALL
SELECT 'serenazgo -> usuarios(SERENO)', ser_o.n, usr_d.n, (usr_d.n - ser_o.n),
       'destino filtra email @serenazgo.local' FROM ser_o, usr_d
UNION ALL
SELECT 'serenazgo -> unidades', ser_o.n, uni_d.n, (uni_d.n - ser_o.n),
       'unidad con responsable @serenazgo.local' FROM ser_o, uni_d
UNION ALL
SELECT 'central -> contactos_emergencia', cen_o.n, cen_d.n, (cen_d.n - cen_o.n),
       'destino incluye 05_catalogos_app.sql' FROM cen_o, cen_d
ORDER BY flujo;

-- Detalle opcional: incidencias migradas por tipo (para cuadrar con el origen)
SELECT t.nombre AS tipo, count(*) AS migradas
  FROM incidencias i JOIN tipos_incidencia t ON t.id = i.tipo_id
 GROUP BY t.nombre ORDER BY migradas DESC;
