-- Datos iniciales (catalogos y datos de prueba en Aguas Verdes: lat -3.4825, lon -80.2450)
--
--  !! SEGURIDAD !!
--  Los usuarios de abajo usan la MISMA contrasena de prueba: CambiarEsto.2026
--  Este archivo es versionado, asi que esa contrasena queda conocida por cualquiera
--  con acceso al repositorio. Antes de exponer el servicio hay que:
--    1. ejecutar UPDATE usuarios SET password_hash = <hash propio> ...
--    2. o desactivar las cuentas: UPDATE usuarios SET activo = FALSE
--  Generar un hash propio:  node -e "console.log(require('bcryptjs').hashSync('TU_CONTRASENA',10))"
-- =====================================================================

INSERT INTO roles(nombre) VALUES ('ADMIN'),('OPERADOR'),('SERENO'),('DIRECTIVO'),('CIUDADANO')
  ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_incidencia(codigo,nombre,prioridad) VALUES
  ('ROBO','Robo / hurto','ALTA'), ('RIA','Riña o disturbio','MEDIA'),
  ('SOSP','Persona sospechosa','MEDIA'), ('ACC','Accidente de tránsito','ALTA'),
  ('VIOL','Violencia familiar','CRITICA'), ('RUIDO','Ruidos molestos','BAJA'),
  ('EMER','Emergencia médica','CRITICA')
  ON CONFLICT (codigo) DO NOTHING;

-- bcrypt("CambiarEsto.2026", 10). CAMBIAR antes de produccion.
INSERT INTO usuarios(dni,nombres,apellidos,email,password_hash,rol_id) VALUES
  ('00000001','Operador','Demo','operador@muniaguasverdes.gob.pe',
   '$2a$10$ly5HnOSQURwAhzhohgAeoOOo/F//ApzJFWX71YG5RsQS9.uBiP3LO',
   (SELECT id FROM roles WHERE nombre='OPERADOR')),
  ('00000002','Admin','Municipal','admin@muniaguasverdes.gob.pe',
   '$2a$10$ly5HnOSQURwAhzhohgAeoOOo/F//ApzJFWX71YG5RsQS9.uBiP3LO',
   (SELECT id FROM roles WHERE nombre='ADMIN')),
  ('00000003','Sereno','Demo','sereno@muniaguasverdes.gob.pe',
   '$2a$10$ly5HnOSQURwAhzhohgAeoOOo/F//ApzJFWX71YG5RsQS9.uBiP3LO',
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