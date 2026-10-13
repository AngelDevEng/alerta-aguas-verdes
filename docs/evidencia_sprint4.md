# Evidencia Sprint 4 — backend Alerta Aguas Verdes

Fecha: 2026-10-13. Rama `main`. URL pública: **https://alerta-aguas-verdes-api.onrender.com**
(health: `/api/v1/health`, Swagger UI: `/api/docs`, OpenAPI JSON: `/api/docs-json`).

Toda la matriz de endpoints y roles se deriva del código (`backend/src/**/*.controller.ts`).
Las respuestas de `/health` y `/api/docs-json` son de la instancia desplegada en Render.

## 1. Inventario de la API (verificado)

- **28 rutas** y **34 operaciones** expuestas bajo el prefijo `/api/v1`
  (fuente: OpenAPI desplegado). Coincide con el conteo del código.
- **Públicas (sin token):** `GET /health`, `POST /auth/login`,
  `POST /auth/login/patrullero`, `POST /auth/refresh`, `POST /alertas`,
  `GET /catalogos/emergencias`, `GET /catalogos/emergencias/whatsapp`.
- **Solo autenticadas (cualquier rol):** `POST /auth/logout`, `GET /auth/me`,
  `GET /catalogos/tipos-incidencia`.

### Matriz rol × endpoint

Leyenda: **P** público, **A** autenticado (cualquier rol), **AD** ADMIN,
**OP** OPERADOR, **SE** SERENO, **DI** DIRECTIVO, **CI** CIUDADANO.

| Método | Ruta | P/A | AD | OP | SE | DI | CI |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|
| GET | `/health` | P | · | · | · | · | · |
| POST | `/auth/login` | P | · | · | · | · | · |
| POST | `/auth/login/patrullero` | P | · | · | · | · | · |
| POST | `/auth/refresh` | P | · | · | · | · | · |
| POST | `/auth/logout` | A | ✓ | ✓ | ✓ | ✓ | ✓ |
| GET | `/auth/me` | A | ✓ | ✓ | ✓ | ✓ | ✓ |
| POST | `/incidencias` | · | ✓ | ✓ | ✓ | · | ✓ |
| GET | `/incidencias` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/incidencias/geojson` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/incidencias/zonas-calor` | · | ✓ | ✓ | · | ✓ | · |
| GET | `/incidencias/:id` | · | ✓ | ✓ | ✓ | ✓ | · |
| PATCH | `/incidencias/:id/estado` | · | ✓ | ✓ | ✓ | · | · |
| PATCH | `/incidencias/:id/asignar` | · | ✓ | ✓ | · | · | · |
| POST | `/incidencias/:id/evidencias` | · | ✓ | ✓ | ✓ | · | · |
| GET | `/incidencias/:id/evidencias` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/unidades` | · | ✓ | ✓ | ✓ | · | · |
| POST | `/unidades` | · | ✓ | · | · | · | · |
| GET | `/unidades/cercanas` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/unidades/:id` | · | ✓ | ✓ | ✓ | ✓ | · |
| PATCH | `/unidades/:id/responsable` | · | ✓ | ✓ | · | · | · |
| POST | `/unidades/:id/ubicaciones` | · | ✓ | ✓ | ✓ | · | · |
| PATCH | `/unidades/:id/estado` | · | ✓ | ✓ | · | · | · |
| PATCH | `/unidades/:id` | · | ✓ | ✓ | · | · | · |
| DELETE | `/unidades/:id` | · | ✓ | · | · | · | · |
| GET | `/unidades/:id/rastro` | · | ✓ | ✓ | · | ✓ | · |
| POST | `/alertas` | P | · | · | · | · | · |
| GET | `/alertas` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/alertas/activas` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/alertas/:id` | · | ✓ | ✓ | ✓ | ✓ | · |
| PATCH | `/alertas/:id/estado` | · | ✓ | ✓ | ✓ | · | · |
| GET | `/catalogos/asociaciones` | · | ✓ | ✓ | ✓ | ✓ | · |
| GET | `/catalogos/emergencias` | P | · | · | · | · | · |
| GET | `/catalogos/emergencias/whatsapp` | P | · | · | · | · | · |
| GET | `/catalogos/tipos-incidencia` | A | ✓ | ✓ | ✓ | ✓ | ✓ |

Decisiones de rol relevantes (en el código):
- `GET /unidades` excluye a DIRECTIVO a propósito y omite el DNI del responsable
  (`unidades.controller.ts:29`, `unidades.service.ts:30-35`).
- `POST /unidades` y `DELETE /unidades/:id` son solo ADMIN.
- `GET /incidencias/zonas-calor` excluye a SERENO.

## 2. Resultados de comandos (entorno local, node v22.16.0 / npm 10.9.2)

| Comando | Resultado |
|---|---|
| `npm ci` | OK (instala exacto desde `package-lock.json`) |
| `npm run build` | OK (`nest build`, salida en `dist/`) |
| `npm run lint` | OK, 0 errores / 0 warnings (ESLint 9 flat config, `eslint.config.mjs`) |
| `npm run test:e2e` | **NO ejecutado localmente** (requiere PostGIS; ver §3) |

## 3. Pruebas end-to-end (`backend/test/4a.e2e-spec.ts`)

Cubren: login, refresh con rotación de un solo uso, catálogos, CRUD de unidades
(campos mínimos sin DNI), zonas de calor (403 por rol), flujo de incidencias,
rate limiting de login, y —ampliado en este sprint— `POST /alertas`,
`GET /unidades/cercanas` y 403 por rol.

**No se ejecutaron en esta máquina** porque el e2e arranca la app contra una BD
PostgreSQL/PostGIS real y aquí no hay Docker activo ni `psql`/`mysql` locales
(el propio archivo advierte: no correr contra datos reales). Se ejecutan en CI.

Añadido este sprint:
- `POST /auth/refresh`: rota el refresh, el access nuevo es distinto y reusar el
  refresh viejo da 401.
- `POST /alertas` (público): acepta SOS sin token y abre incidencia; sin
  latitud/longitud → 400.
- `GET /unidades/cercanas`: lista las unidades DISPONIBLES (incluye la SER-01
  sembrada) y exige token (401 sin token).
- 403 por rol: SERENO no crea unidades; DIRECTIVO no cambia el estado de alerta.

## 4. Integración continua (`.github/workflows/backend-ci.yml`)

En cada push/PR a `main`:
1. Servicio `postgis/postgis:16-3.4` (health-check con `pg_isready`).
2. `npm ci` → `npm run build` → `npm run lint`.
3. Carga de esquema y seed (`01`…`06`) con un script Node usando `pg`.
4. `npm run test:e2e` contra ese PostGIS efímero.

Variables de entorno del job: `DATABASE_URL` (PostGIS local), `DB_SSL=false`,
`JWT_SECRET`, `SUPABASE_URL`/`SUPABASE_SERVICE_KEY` (dummies: `EvidenciasService`
exige las variables al instanciarse, pero el e2e no sube archivos).

> Nota: la primera ejecución de CI no está verificada en esta máquina (sin
> `gh` ni Docker). Al hacer push, revisar la pestaña Actions.

## 5. Evidencia de despliegue

`GET https://alerta-aguas-verdes-api.onrender.com/api/v1/health` → **200**:

```json
{"status":"ok","postgis":"3.3 USE_GEOS=1 USE_PROJ=1 USE_STATS=1","timestamp":"2026-10-13T22:20:07.358Z"}
```

`GET https://alerta-aguas-verdes-api.onrender.com/api/docs-json` → **200**,
28 rutas / 34 operaciones (Swagger UI en `/api/docs`).

## 6. Cómo reproducir

```powershell
# Backend (desde backend/)
npm ci
npm run build
npm run lint

# E2E (requiere un PostgreSQL con PostGIS y las vars de entorno)
$env:DATABASE_URL="postgres://postgres:postgres@localhost:5432/alerta_test"
$env:DB_SSL="false"
$env:JWT_SECRET="dev-secret"
$env:SUPABASE_URL="https://example.supabase.co"
$env:SUPABASE_SERVICE_KEY="dummy"
npm run test:e2e
```

Carga de esquema (equivalente a la del CI):

```powershell
node -e "const fs=require('fs');const{Client}=require('pg');(async()=>{const c=new Client({connectionString:process.env.DATABASE_URL});await c.connect();for(const f of ['01_schema.sql','02_indices_triggers.sql','03_seed.sql','04_auth_alertas.sql','05_catalogos_app.sql','06_baja_logica_unidades.sql']){await c.query(fs.readFileSync('../database/'+f,'utf8'));}await c.end();})()"
```
