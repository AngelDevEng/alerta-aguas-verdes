# Alerta Aguas Verdes - Base de datos y backend

## 1. Base de datos (Supabase)
1. Crear proyecto en Supabase. En SQL Editor ejecutar, en orden:
   `database/01_schema.sql`, `database/02_indices_triggers.sql`, `database/03_seed.sql`,
   `database/04_auth_alertas.sql`.
2. Verificar con `database/99_verificacion.sql`.
3. Migrar los datos de XAMPP: ver `database/migracion/README_migracion_xampp.md`.
4. Storage > crear bucket `evidencias` (publico).

## 2. Backend en local
```
cd backend
cp .env.example .env     # completar DATABASE_URL, JWT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_KEY
npm install
npm run start:dev        # http://localhost:3000/api/docs
```

## 3. Autenticacion
Todos los endpoints exigen `Authorization: Bearer <accessToken>`, salvo:
`POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `GET /api/v1/health`
y `POST /api/v1/alertas` (el ciudadano que pulsa SOS no tiene cuenta).

```
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"dni":"00000001","password":"CambiarEsto.2026"}'
```

El access token dura 15 min (`JWT_EXPIRES_IN`). El refresh token dura 30 dias,
se rota en cada uso y se guarda solo su SHA-256.

### Roles
| Rol | Puede |
|---|---|
| `ADMIN` | Todo, incluida la creacion de unidades |
| `OPERADOR` | Despachar, cambiar estados, ver todo |
| `SERENO` | Reportar incidencias y GPS de su unidad, atender alertas |
| `DIRECTIVO` | Solo lectura |
| `CIUDADANO` | Reportar incidencias |

Para proteger un endpoint se usan `@Roles(...)`; sin ese decorador basta con estar autenticado.

## 4. Alertas SOS
`POST /api/v1/alertas` es publico y ademas abre una incidencia `CRITICA` de tipo `EMER`,
de modo que la alerta entra al flujo normal de despacho. Al cerrarla se cierra la incidencia
y se libera la unidad asignada.

## 5. Despliegue en Render
Subir a GitHub y crear un "Blueprint" en Render con `render.yaml`; cargar las variables de entorno.
`JWT_SECRET` se genera solo (`generateValue: true`); hay que definir `CORS_ORIGIN` con el dominio real.
Probar: `https://<tu-servicio>.onrender.com/api/v1/health`

## Aviso de seguridad
Las credenciales de MySQL que aparecen en claro dentro de `AppSerenazgoseguro-legacy/`
(`WsLs9cnQ2a`, `XnfgZ%MfNO%`), su `AUTH_SECRET` y la base de datos en produccion deben
rotarse: al estar en el historial de git, no basta con borrarlas del codigo.
