-- Datos iniciales (catalogos y datos de prueba en Aguas Verdes: lat -3.4825, lon -80.2450)
INSERT INTO roles(nombre) VALUES ('ADMIN'),('OPERADOR'),('SERENO'),('DIRECTIVO');

INSERT INTO tipos_incidencia(codigo,nombre,prioridad) VALUES
 ('ROBO','Robo / hurto','ALTA'), ('RIA','Riña o disturbio','MEDIA'),
 ('SOSP','Persona sospechosa','MEDIA'), ('ACC','Accidente de tránsito','ALTA'),
 ('VIOL','Violencia familiar','CRITICA'), ('RUIDO','Ruidos molestos','BAJA'),
 ('EMER','Emergencia médica','CRITICA');

INSERT INTO usuarios(dni,nombres,apellidos,email,password_hash,rol_id) VALUES
 ('00000001','Operador','Demo','operador@muniaguasverdes.gob.pe','$2b$10$PLACEHOLDER_REEMPLAZAR_EN_H4',(SELECT id FROM roles WHERE nombre='OPERADOR'));

INSERT INTO unidades_serenazgo(codigo,tipo,placa,ultima_ubicacion,ultima_actualizacion) VALUES
 ('SER-01','PATRULLA','EGA-123', ST_SetSRID(ST_MakePoint(-80.2455,-3.4830),4326)::geography, now()),
 ('SER-02','MOTOCICLETA','MDV-456', ST_SetSRID(ST_MakePoint(-80.2410,-3.4790),4326)::geography, now()),
 ('SER-03','PIE',NULL,           ST_SetSRID(ST_MakePoint(-80.2470,-3.4850),4326)::geography, now());

INSERT INTO incidencias(tipo_id,descripcion,prioridad,ubicacion,referencia) VALUES
 ((SELECT id FROM tipos_incidencia WHERE codigo='ROBO'),'Robo al paso cerca del control fronterizo','ALTA',
   ST_SetSRID(ST_MakePoint(-80.2462,-3.4817),4326)::geography,'Av. República del Perú');
