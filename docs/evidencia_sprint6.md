# Evidencia Sprint 6

## Endpoints
- GET /api/v1/incidencias/estadisticas (ADMIN, OPERADOR, DIRECTIVO)
- GET /api/v1/incidencias/zonas-calor (ADMIN, OPERADOR, DIRECTIVO)

## Matriz de roles
| Rol | estadisticas | zonas-calor |
|---|---|---|
| ADMIN | 200 | 200 |
| OPERADOR | 200 | 200 |
| DIRECTIVO | 200 | 200 |
| SERENO | 403 | 403 |
| CIUDADANO | 403 | 403 |

## Resultados de tests
(pendiente de run real en CI)

## Capturas
(pendiente)
