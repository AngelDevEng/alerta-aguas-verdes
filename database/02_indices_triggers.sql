-- =====================================================================
-- Indices, triggers y funciones geoespaciales  (Sprint 1 - H1 / Sprint 2 - H2)
-- =====================================================================

-- ---------- Indices espaciales (GiST) ----------
CREATE INDEX idx_incidencias_ubicacion   ON incidencias           USING GIST (ubicacion);
CREATE INDEX idx_unidades_ubicacion      ON unidades_serenazgo    USING GIST (ultima_ubicacion);
CREATE INDEX idx_evidencias_ubicacion    ON evidencias_multimedia USING GIST (ubicacion);
CREATE INDEX idx_ubic_unidad_ubicacion   ON ubicaciones_unidad    USING GIST (ubicacion);

-- ---------- Indices B-tree ----------
CREATE INDEX idx_incidencias_estado_fecha ON incidencias (estado, ocurrido_en DESC);
CREATE INDEX idx_incidencias_tipo         ON incidencias (tipo_id);
CREATE INDEX idx_incidencias_unidad       ON incidencias (unidad_asignada_id);
CREATE INDEX idx_evidencias_incidencia    ON evidencias_multimedia (incidencia_id);
CREATE INDEX idx_historial_incidencia     ON historial_incidencia (incidencia_id, registrado_en);
CREATE INDEX idx_ubic_unidad_tiempo       ON ubicaciones_unidad (unidad_id, registrado_en DESC);
CREATE INDEX idx_unidades_estado          ON unidades_serenazgo (estado);

-- ---------- Trigger: actualizado_en ----------
CREATE OR REPLACE FUNCTION fn_set_actualizado_en() RETURNS trigger AS $$
BEGIN NEW.actualizado_en := now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_upd   BEFORE UPDATE ON usuarios           FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER trg_unidades_upd   BEFORE UPDATE ON unidades_serenazgo FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER trg_incidencias_upd BEFORE UPDATE ON incidencias       FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();

-- ---------- Trigger: historial de estados (trazabilidad) ----------
CREATE OR REPLACE FUNCTION fn_historial_estado() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO historial_incidencia(incidencia_id, estado_anterior, estado_nuevo, unidad_id)
    VALUES (NEW.id, NULL, NEW.estado, NEW.unidad_asignada_id);
  ELSIF NEW.estado IS DISTINCT FROM OLD.estado THEN
    INSERT INTO historial_incidencia(incidencia_id, estado_anterior, estado_nuevo, unidad_id)
    VALUES (NEW.id, OLD.estado, NEW.estado, NEW.unidad_asignada_id);
    IF NEW.estado = 'ATENDIDA' AND NEW.atendido_en IS NULL THEN NEW.atendido_en := now(); END IF;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incidencias_hist_ins AFTER INSERT ON incidencias FOR EACH ROW EXECUTE FUNCTION fn_historial_estado();
-- BEFORE UPDATE para poder completar atendido_en
CREATE TRIGGER trg_incidencias_hist_upd BEFORE UPDATE ON incidencias FOR EACH ROW EXECUTE FUNCTION fn_historial_estado();

-- ---------- Trigger: sincroniza ultima_ubicacion de la unidad ----------
CREATE OR REPLACE FUNCTION fn_actualizar_ultima_ubicacion() RETURNS trigger AS $$
BEGIN
  UPDATE unidades_serenazgo
     SET ultima_ubicacion = NEW.ubicacion, ultima_actualizacion = NEW.registrado_en
   WHERE id = NEW.unidad_id;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ubic_unidad_ai AFTER INSERT ON ubicaciones_unidad
FOR EACH ROW EXECUTE FUNCTION fn_actualizar_ultima_ubicacion();

-- ---------- Funcion: unidades cercanas a un punto (H2) ----------
CREATE OR REPLACE FUNCTION fn_unidades_cercanas(p_lon DOUBLE PRECISION, p_lat DOUBLE PRECISION, p_radio_m INTEGER DEFAULT 2000)
RETURNS TABLE (id UUID, codigo VARCHAR, tipo tipo_unidad, distancia_m DOUBLE PRECISION) AS $$
  SELECT u.id, u.codigo, u.tipo,
         ST_Distance(u.ultima_ubicacion, ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography) AS distancia_m
    FROM unidades_serenazgo u
   WHERE u.estado = 'DISPONIBLE'
     AND u.ultima_ubicacion IS NOT NULL
     AND ST_DWithin(u.ultima_ubicacion, ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography, p_radio_m)
   ORDER BY distancia_m;
$$ LANGUAGE sql STABLE;

-- ---------- Vista GeoJSON para mapas / dashboards ----------
CREATE OR REPLACE VIEW v_incidencias_geojson AS
SELECT i.id, i.codigo, t.nombre AS tipo, i.estado, i.prioridad, i.ocurrido_en,
       jsonb_build_object('type','Feature',
         'geometry', ST_AsGeoJSON(i.ubicacion::geometry)::jsonb,
         'properties', jsonb_build_object('codigo',i.codigo,'tipo',t.nombre,'estado',i.estado,'prioridad',i.prioridad)) AS feature
  FROM incidencias i JOIN tipos_incidencia t ON t.id = i.tipo_id;
