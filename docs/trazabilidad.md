# Matriz de trazabilidad (RF/RNF -> HU -> implementacion -> prueba -> evidencia -> estado)

| ID | HU | Archivos | Prueba | Evidencia | Estado |
|---|---|---|---|---|---|
| RF01 | HU3.2 | backend/src/incidencias/incidencias.controller.ts, incidencias.service.ts | backend/test/4a.e2e-spec.ts | CI backend-ci | PARCIAL |
| RF02 | HU2.2 | backend/src/evidencias/evidencias.service.ts | (sin e2e de subida) | - | NO EJECUTADO |
| RF03 | HU3.2 | incidencias.controller.ts, incidencias.service.ts | 4a.e2e-spec.ts | - | PARCIAL |
| RF04 | HU3.3 | backend/src/unidades/unidades.controller.ts, unidades.service.ts | (sin e2e de unidades) | - | NO EJECUTADO |
| RF05 | HU3.3 | unidades.service.ts (asignar) | (sin e2e) | - | NO EJECUTADO |
| RF06 | HU2.3 | unidades.service.ts (cercanas) | (sin e2e) | - | NO EJECUTADO |
| RF07 | HU1.4 | database/02_indices_triggers.sql | SQL trigger | - | NO EJECUTADO |
| RF08 | HU4.1 | backend/src/auth/auth.service.ts, jwt strategy | 4a.e2e-spec.ts | CI | PARCIAL |
| RF09 | HU5.1,HU5.2 | backend/src/realtime/realtime.gateway.ts, realtime.service.ts | gateway.e2e-spec.ts (sin token) | CI | PARCIAL |
| RF10 | HU6.1,HU6.2 | incidencias.controller.ts (estadisticas, zonas-calor) | sprint6.e2e-spec.ts | CI | PARCIAL |
| RF11 | HU2.4 | unidades.service.ts (ubicaciones), ubicaciones_unidad | (sin e2e) | - | NO EJECUTADO |
| RF12 | HU1.3 | database/migracion/* | conteos origen/destino | manual | NO EJECUTADO |
| RF13 | HU4.2 | auth/roles guards | matriz rol x endpoint | - | PARCIAL |
| RF14 | HU5.3 | alertas/alertas.service.ts | 4a.e2e-spec.ts | - | PARCIAL |
| RF15 | HU5.3 | realtime.service.ts notificarNuevaAlerta | gateway tests | - | NO EJECUTADO |
| RF16 | HU5.4 | mobile/lib/core/realtime/socket_service.dart, mapa_en_vivo_page.dart | flutter analyze | CI | PARCIAL |
| RF17 | HU6.3 | mobile/lib/features/dashboard/presentation/dashboard_page.dart | flutter analyze | - | PARCIAL |

| RNF01 | HU3.1 | render.yaml | /health 200 PostGIS | produccion | CUMPLE |
| RNF02 | HU4.3 | helmet, guards, param queries, .env, secret-scan.yml | CI secret scan | CI | PARCIAL |
| RNF03 | HU1.1 | database/01_schema.sql | CI backend (schema load) | CI | CUMPLE |
| RNF04 | HU1.2,HU2.1 | database/02_indices_triggers.sql | (sin benchmark) | - | NO EJECUTADO |
| RNF05 | HU3.4 | main.ts prefix, swagger | /api/docs 200 | produccion | CUMPLE |
| RNF06 | HU4.4 | guards, roles | (sin evidencia bucket privado) | - | PARCIAL |
| RNF07 | HU1.1 | modulos NestJS, database/NN_*.sql | build CI | CI | CUMPLE |
| RNF08 | HU5.2 | gateway, serverTime | (pendiente medicion) | - | NO EJECUTADO |
| RNF09 | HU1.4,HU2.2 | historial trigger, evidencias SHA-256 | (sin e2e) | - | NO EJECUTADO |
| RNF10 | HU6.4 | .github/workflows/* | CI verde (PR #8) | CI | CUMPLE |
| RNF11 | HU5.1 | gateway validaciones | gateway.e2e-spec.ts | CI | PARCIAL |
| RNF12 | HU5.4 | socket_service.dart | flutter analyze | CI | PARCIAL |
| RNF13 | HU6.4 | docs/entrega/* | - | - | PARCIAL |
| RNF14 | HU4.3 | .gitignore, rotacion | (pendiente rotacion real) | - | NO EJECUTADO |

## Dependencias externas
- RF12: requiere dump MySQL y autorizacion del responsable.
- RNF01: decision del Product Owner sobre plan de Render (sin suspension).
- RNF14: rotacion de claves legacy en produccion (pendiente).
