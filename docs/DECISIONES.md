# Decisiones vigentes

> 2026-10-07. Decisiones confirmadas por el responsable del proyecto y contrastadas
> con `docs/plan.md`, `docs/auditoria-inicial.md`, `docs/MAPABASE.md` y el código
> actual. Ante conflicto entre este archivo y otro documento, manda este; ante
> conflicto entre este archivo y el responsable, manda el responsable (y este se
> actualiza).

## 1. Proyecto

- **Título**: Modernización del sistema de alerta Aguas Verdes mediante la
  implementación de servicios en la nube y funcionalidades de monitoreo en tiempo
  real.
- **Metodología**: PMI + SCRUM.
- **Historias de usuario**: H1 a H6:
  - H1 — Base relacional.
  - H2 — Geoespacial + evidencias.
  - H3 — Backend en la nube + API REST.
  - H4 — JWT + RBAC.
  - H5 — Tiempo real (WebSockets).
  - H6 — Dashboards / estadísticas.

## 2. Cliente oficial: Flutter

- Cliente móvil oficial: **Flutter** (Android e iOS) en `mobile/`.
- El **Kotlin legacy NO se modifica**: es especificación de diseño y funciones y
  respaldo (repo privado aparte; ver estructura en `docs/plan.md`).
- **iOS**: configurado (permisos, Info.plist, capacidades), **sin afirmar que
  funciona** sin ejecución real (dispositivo, simulador o TestFlight) con evidencia.

## 3. Tiempo real

- **WebSocket con respaldo REST** (polling como fallback).
- **Sin FCM** (push) y **sin panel web**: fuera de H1–H6 y del MVP.

## 4. Login por placa

- Cadena: `placa → unidades_serenazgo.placa → responsable_id → usuarios → bcrypt`.
- **Sin cambios de esquema** de `usuarios`.
- Rate limit por IP y por placa, comparación bcrypt contra hash dummy cuando la
  placa no existe (igualar tiempos) y mensaje genérico de error (anti-enumeración).
- Unidades sin placa (tipo PIE) siguen entrando por DNI.
- Evidencia: `backend/src/auth/auth.service.ts` (`loginPatrullero`, rate limit y
  `HASH_DUMMY`).

## 5. Cambios de esquema de base de datos

- Solo con **migraciones SQL idempotentes** de numeración incremental `NN_*.sql`
  (la última existente es `06_baja_logica_unidades.sql`; la siguiente será
  `07_*.sql`) y **con aprobación previa** del responsable antes de ejecutarlas.
- Las migraciones siguen aplicándose manualmente (no las corre el deploy).

## 6. Zonas de calor (H6)

- Según `docs/MAPABASE.md`: grilla de ~100 m, proyección **EPSG:32717 (UTM 17S)**,
  `ST_SnapToGrid`, respuesta `[{lat, lng, peso, tipo_mas_comun}]` con **solo datos
  agregados** (nunca filas individuales de incidencias).
- Umbrales de color: 1–3 / 4–8 / 9+.
- Evidencia: `backend/src/incidencias/incidencias.service.ts` (zonas de calor).

## 7. Datos sensibles

- Datos personales y credenciales **fuera de Git** (`.gitignore`: `.env*`,
  `CREDENCIALES*.txt`, `local.properties`).
- **Los e2e nunca apuntan a Supabase**: corren exclusivamente contra una base de
  pruebas local (`.env.test`, gitignored). Supabase es el entorno de
  demostración/despliegue, no mesa de pruebas.

## 8. Informes

- El informe debe coincidir **exactamente** con lo implementado; no se citan cifras
  sin evidencia verificable (`ruta:línea` o comando de verificación).

## Notas de contraste con otros documentos

- `docs/plan.md` (paso 4f): indica que el SDK de Flutter no está instalado →
  **desactualizado**: Flutter 3.47.6 está en `C:\Users\dahua\dev\flutter`.
- `docs/auditoria-inicial.md` (fila "Pruebas"): "backend 0 tests" → **desactualizado**:
  existe `backend/test/4a.e2e-spec.ts` con `npm run test:e2e`.
- `backend/test/4a.e2e-spec.ts` hoy está escrito para correr contra Supabase
  ("Corre contra la base real de Supabase") → **en contradicción con la decisión 7**;
  pendiente de apuntarlo a la BD local de pruebas antes de volver a correrlo.
