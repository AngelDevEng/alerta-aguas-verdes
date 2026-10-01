# Migración de la BD en XAMPP (MySQL/MariaDB) a PostgreSQL en Supabase

> Los nombres de tablas/columnas de `legacy_*` son un EJEMPLO. Ajústalos a tu base real
> (ejecuta `SHOW TABLES;` y `DESCRIBE <tabla>;` en phpMyAdmin).

## 1. Exportar desde XAMPP a CSV
En phpMyAdmin → tabla → Exportar → formato CSV (con cabecera de columnas), UTF-8.
O por consola:
```
mysql -u root -p -e "SELECT * FROM alertas" bd_alerta --batch > alertas.tsv
```

## 2. Crear tablas "staging" en Supabase (SQL Editor)
Ejecutar `staging_template.sql` (crea `legacy_incidencias`, etc., todo en texto).

## 3. Importar los CSV
Supabase → Table Editor → tabla `legacy_*` → Import data from CSV.
Alternativa: `\copy legacy_incidencias FROM 'alertas.csv' CSV HEADER` desde psql.

## 4. Transformar hacia el modelo definitivo
Ejecutar la sección INSERT ... SELECT de `staging_template.sql` (convierte lat/lon a
`GEOGRAPHY(Point,4326)`, mapea tipos y estados).

## 5. Validar (evidencia para el informe)
```
SELECT count(*) FROM legacy_incidencias;   -- origen
SELECT count(*) FROM incidencias;          -- destino: deben coincidir
```

## 6. Limpiar
`DROP TABLE legacy_incidencias;` cuando esté validado.
