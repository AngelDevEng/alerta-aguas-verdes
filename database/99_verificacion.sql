-- Consultas de verificacion (capturas para el informe)
SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY 1;
SELECT indexname, tablename FROM pg_indexes WHERE schemaname='public' ORDER BY tablename;
SELECT * FROM fn_unidades_cercanas(-80.2450,-3.4825,2000);
SELECT codigo, estado, ST_AsText(ubicacion::geometry) FROM incidencias;
SELECT * FROM historial_incidencia;
