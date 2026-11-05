-- Cuentas de prueba (ejecutar solo en BD de prueba)
INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
VALUES
  ('99999991','Test','Admin','t1@x.com', crypt('TestPass1!', gen_salt('bf',12)), (SELECT id FROM roles WHERE nombre='ADMIN')),
  ('99999992','Test','Operador','t2@x.com', crypt('TestPass2!', gen_salt('bf',12)), (SELECT id FROM roles WHERE nombre='OPERADOR')),
  ('99999993','Test','Directivo','t3@x.com', crypt('TestPass3!', gen_salt('bf',12)), (SELECT id FROM roles WHERE nombre='DIRECTIVO')),
  ('99999994','Test','Ciudadano','t4@x.com', crypt('TestPass4!', gen_salt('bf',12)), (SELECT id FROM roles WHERE nombre='CIUDADANO'));

INSERT INTO unidades_serenazgo (codigo, tipo, placa, estado) VALUES ('TEST-U1','MOTO','T-001','DISPONIBLE') ON CONFLICT DO NOTHING;
INSERT INTO usuarios (dni, nombres, apellidos, email, password_hash, rol_id)
VALUES ('99999995','Test','Sereno','t5@x.com', crypt('TestPass5!', gen_salt('bf',12)), (SELECT id FROM roles WHERE nombre='SERENO'));
UPDATE unidades_serenazgo SET responsable_id = (SELECT id FROM usuarios WHERE dni='99999995') WHERE codigo='TEST-U1';

-- Limpieza
DELETE FROM ubicaciones_unidad WHERE unidad_id IN (SELECT id FROM unidades_serenazgo WHERE codigo='TEST-U1');
DELETE FROM alertas WHERE unidad_asignada_id IN (SELECT id FROM unidades_serenazgo WHERE codigo='TEST-U1');
DELETE FROM usuarios WHERE dni IN ('99999991','99999992','99999993','99999994','99999995');
DELETE FROM unidades_serenazgo WHERE codigo='TEST-U1';
