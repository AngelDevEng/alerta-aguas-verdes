# Auditoría inicial (solo lectura) — 2026-10-04

Auditoría del estado del proyecto antes del control de versiones. Toda afirmación
tiene evidencia `ruta:línea`. Lo no comprobable se marca NO EXISTE / NO VERIFICADO.
Actualizada con las correcciones detectadas al montar el repo (estructura real de
tests, hallazgos del historial remoto).

## Estado por historia de usuario

| H | Estado | Evidencia clave |
|---|---|---|
| H1 base relacional | **Parcial** | 8 tablas + ENUMs + CHECKs en `database/01_schema.sql`. Migración de datos reales: solo plantilla (`database/migracion/staging_template.sql:3` se declara "PLANTILLA"). |
| H2 geoespacial + evidencias | **Parcial** | PostGIS: 4 índices GiST, `fn_unidades_cercanas`, vista GeoJSON (`02_indices_triggers.sql:6-76`). Evidencias con SHA-256 y UNIQUE por incidencia (`01_schema.sql:91-96`), upload a Supabase Storage (`evidencias.service.ts:33`). |
| H3 backend en la nube + API REST | **Parcial** | 29 endpoints (16 GET, 8 POST, 5 PATCH). `render.yaml`, `Dockerfile` multietapa. Sin evidencia de ejecución (node no instalado, sin node_modules, sin URL de Render). |
| H4 JWT + RBAC | **Hecho en código** | Guards globales `JwtAuthGuard` (rehidrata desde BD) y `RolesGuard` (`app.module.ts:37-38`), 5 roles, refresh opaco con rotación de un solo uso y SHA-256 en BD (`auth.service.ts:69,114-116`). Sin rate limiting ni pruebas. |
| H5 tiempo real WebSockets | **No iniciado** | 0 coincidencias de WebSocket/socket.io/gateway en backend, pubspec y package-lock. Sin eventos, sin polling en Flutter. El legacy Kotlin hace short polling cada 7 s (`SerenazgoRepository.kt:366`). |
| H6 dashboards/estadísticas | **No iniciado** | No hay endpoint de estadísticas. Contrato de zonas de calor especificado en `docs/MAPABASE.md` (grilla ~100 m, `peso`, `tipo_mas_comun`). |

## Cifras verificadas

- **Tablas: 12** (8 en `01_schema.sql` + `refresh_tokens`, `alertas` en `04` + `asociaciones`, `contactos_emergencia` en `05`). Vistas: 2. Índices explícitos: 16 (4 GiST). Triggers: 6. Funciones: 4. Tipos ENUM: 5.
- **Endpoints: 29** — 6 públicos (`/health`, `/auth/login`, `/auth/refresh`, `POST /alertas`, 2 de catálogos), 21 con `@Roles`, 2 solo autenticados (`/auth/logout`, `/auth/me`).
- **Versiones (lockfile):** NestJS 10.4.22, TypeORM 0.3.31 (solo como `DataSource.query`, sin entidades), @supabase/supabase-js 2.117.2, pg 8.23.1, helmet 7.2.0, bcryptjs 2.4.3, TypeScript 5.9.3. Docker: `node:22-alpine`. PostgreSQL/PostGIS: versión no fijada.
- **Pruebas:** backend 0 (sin jest, sin specs). Flutter: **79 casos en 10 archivos** (`mobile/test/**`), todas unitarias; `bloc_test`/`mocktail` en dev_dependencies sin usar. CI: NO EXISTE (sin `.github/`).
- **TypeScript:** `strictNullChecks` sí, `strict` no; sin ESLint/Prettier. 0 TODOs, 0 `console.log` en `backend/src`.

## Seguridad (resumen de hallazgos)

1. **`DEV_MODE = true` en el legacy** (`utils/auth_token.php:18`): bypass total de
   autenticación con payload privilegiado por defecto (`:91-94`). (El archivo ya no
   está en ningún repo: ver estructura en `docs/plan.md`.)
2. **PII real y credenciales en el legacy**: dump `serenazgo.sql` (4 personas con
   nombre/DNI/placa/foto + 4 hashes bcrypt), credenciales MySQL en `conexion.php`,
   `AUTH_SECRET` en `auth_token.php`, login en claro en `php/test_endpoints.sh:15`,
   `error_log` de 3,7 MB con rutas del servidor de producción. Todo ello quedó
   **fuera de cualquier repo** en el paso 0.
3. **Historial remoto**: el seed viejo (commits `4bca956`/`88fd138`) contenía una
   contraseña de prueba conocida en un comentario + su hash bcrypt; se eliminó del
   árbol en `5c29071` pero **permanece recuperable en el historial**. Rotación ya
   contemplada por `backend/scripts/rotar-credenciales.mjs`; la reescritura del
   historial es decisión del responsable. Falsos positivos descartados:
   `.env.example` (placeholder `<password>`) y fixtures de test en Dart.
4. **Backend nuevo**: sin bypass dev; `getOrThrow` en las 4 variables críticas;
   mensaje anti-enumeración de DNI; seed con hash inservible. Pendientes: rate
   limiting en login, DNI en log (`auth.service.ts:34`), Dockerfile corre como root,
   sin `enableShutdownHooks()`, CORS_ORIGIN sin fijar en producción.

## Compatibilidad con el Kotlin original

- La app Kotlin sigue apuntando a `http://192.168.1.49/serenazgo_backend/hosting`
  (`Constants.kt:6,10`) con `cleartextTrafficPermitted="true"`. No consume la API
  nueva. De los 15 métodos de `SerenazgoRepository`: 1 equivalente, 5 adaptables,
  9 rotos o sin endpoint nuevo (incluye editar/eliminar unidad y zonas de calor).
- IDs: legacy `Int` vs nuevo `UUID`; sin capa de traducción. Roles: legacy
  `PATRULLERO` vs nuevos `ADMIN/OPERADOR/SERENO/DIRECTIVO/CIUDADANO`; el login por
  placa no existe en el backend nuevo (se implementa en el paso 4a).
- El front oficial es Flutter (`mobile/lib`, clean architecture), pero no llama a
  `/alertas` (sin SOS) y el mapa es un placeholder (`app_router.dart:193-212`).

## Riesgos top (pre-paso 0)

1. ~~Sin Git en absoluto~~ → resuelto en paso 0 (historial del remoto adoptado).
2. `DEV_MODE=true` + PII/credenciales del legacy → contenido: fuera de todo repo.
3. Sin tiempo real (H5) aunque el título lo exige.
4. Cero tests backend + cero CI.
5. Secreto de prueba recuperable en el historial remoto (rotación obligatoria).

## Calificación (pre-paso 0)

Arquitectura 6/10 (backend sin capa Repository, SQL en los 6 services; front
Flutter con clean architecture completa). Seguridad 4/10. Completitud 4/10
(H1 60%, H2 95%, H3 60%, H4 85%, H5 0%, H6 0%, sin CI/tests/verificación de despliegue).
