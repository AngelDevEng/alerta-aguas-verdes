-- Datos iniciales (catalogos y datos de prueba en Aguas Verdes: lat -3.4825, lon -80.2450)
--
--  !! SEGURIDAD !!
--  Este archivo esta versionado: NO puede contener una contrasena que sirva.
--  Los tres usuarios se insertan con un hash invalido por diseño, asi que
--  arrancar con ellos es imposible hasta que asignes una contrasena real.
--
--  Pasos para habilitar cada cuenta (desde el backend, donde esta bcryptjs):
--    1. generar hash:  node -e "console.log(require('bcryptjs').hashSync(process.argv[1],12))" 'MI_CONTRASENA'
--    2. asignarlo:      UPDATE usuarios SET password_hash = '<hash>' WHERE dni = '00000001'
--
--  Para pruebas locales efimeras se puede desactivar el acceso en vez de eso:
--    UPDATE usuarios SET activo = FALSE
--
--  Rotacion masiva: backend/scripts/rotar-credenciales.mjs
-- =====================================================================

INSERT INTO roles(nombre) VALUES ('ADMIN'),('OPERADOR'),('SERENO'),('DIRECTIVO'),('CIUDADANO')
  ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_incidencia(codigo,nombre,prioridad) VALUES
  ('ROBO','Robo / hurto','ALTA'), ('RIA','Riña o disturbio','MEDIA'),
  ('SOSP','Persona sospechosa','MEDIA'), ('ACC','Accidente de tránsito','ALTA'),
  ('VIOL','Violencia familiar','CRITICA'), ('RUIDO','Ruidos molestos','BAJA'),
  ('EMER','Emergencia médica','CRITICA')
  ON CONFLICT (codigo) DO NOTHING;

-- Hash inservible: bcrypt de una cadena aleatoria de 48 bytes descartada.
-- Nadie puede autenticarse con estas cuentas hasta asignar un hash propio
-- (ver instrucciones de seguridad al inicio del archivo).
INSERT INTO usuarios(dni,nombres,apellidos,email,password_hash,rol_id) VALUES
  ('00000001','Operador','Demo','operador@muniaguasverdes.gob.pe',
   '$2a$12$EHidfmMr68yo/wRkc9HQfezu8Or5OvFzdPEuCK8kk9BpmJSF99ry2',
   (SELECT id FROM roles WHERE nombre='OPERADOR')),
  ('00000002','Admin','Municipal','admin@muniaguasverdes.gob.pe',
   '$2a$12$EHidfmMr68yo/wRkc9HQfezu8Or5OvFzdPEuCK8kk9BpmJSF99ry2',
   (SELECT id FROM roles WHERE nombre='ADMIN')),
  ('00000003','Sereno','Demo','sereno@muniaguasverdes.gob.pe',
   '$2a$12$EHidfmMr68yo/wRkc9HQfezu8Or5OvFzdPEuCK8kk9BpmJSF99ry2',
   (SELECT id FROM roles WHERE nombre='SERENO'))
  ON CONFLICT (dni) DO NOTHING;

INSERT INTO unidades_serenazgo(codigo,tipo,placa,ultima_ubicacion,ultima_actualizacion) VALUES
  ('SER-01','PATRULLA','EGA-123', ST_SetSRID(ST_MakePoint(-80.2455,-3.4830),4326)::geography, now()),
  ('SER-02','MOTOCICLETA','MDV-456', ST_SetSRID(ST_MakePoint(-80.2410,-3.4790),4326)::geography, now()),
  ('SER-03','PIE',NULL,           ST_SetSRID(ST_MakePoint(-80.2470,-3.4850),4326)::geography, now())
  ON CONFLICT (codigo) DO NOTHING;

INSERT INTO incidencias(tipo_id,descripcion,prioridad,ubicacion,referencia,reportado_por) VALUES
  ((SELECT id FROM tipos_incidencia WHERE codigo='ROBO'),'Robo al paso cerca del control fronterizo','ALTA',
   ST_SetSRID(ST_MakePoint(-80.2462,-3.4817),4326)::geography,'Av. República del Perú',
   (SELECT id FROM usuarios WHERE dni='00000001'));