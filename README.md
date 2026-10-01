# Alerta Aguas Verdes - Base de datos y backend (Sprints 1 a 3)

## 1. Base de datos (Supabase)
1. Crear proyecto en Supabase. En SQL Editor ejecutar, en orden:
   `database/01_schema.sql`, `database/02_indices_triggers.sql`, `database/03_seed.sql`.
2. Verificar con `database/99_verificacion.sql`.
3. Migrar los datos de XAMPP: ver `database/migracion/README_migracion_xampp.md`.
4. Storage > crear bucket `evidencias` (publico).

## 2. Backend en local
```
cd backend
cp .env.example .env     # completar DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_KEY
npm install
npm run start:dev        # http://localhost:3000/api/docs
```

## 3. Despliegue en Render
Subir a GitHub y crear un "Blueprint" en Render con `render.yaml`; cargar las variables de entorno.
Probar: `https://<tu-servicio>.onrender.com/api/v1/health`
