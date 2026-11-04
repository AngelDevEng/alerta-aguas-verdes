# Evidencia Sprint 5 - Tiempo real

## Eventos del gateway (namespace /ws)
- conectado, error_auth, error
- ping_latencia / pong_latencia (medicion con reloj del servidor)
- posicion_unidad (publicacion y broadcast a sala central)
- nueva_alerta_sos, cambio_estado_incidencia, cambio_estado_unidad (RealtimeService)

## Matriz de roles WebSocket
| Rol | Sala central | Publicar posicion | Condicion |
|---|---|---|---|
| ADMIN | si | si (cualquier unidad) | - |
| OPERADOR | si | si (cualquier unidad) | - |
| SERENO | no | solo unidad asignada (responsable_id) | validacion BD |
| DIRECTIVO | si | no | - |
| CIUDADANO | no | no | - |

## Validaciones implementadas
- Token JWT requerido; token vencido en conexion abierta cierra conexion.
- Revalidacion de usuario activo en BD en conexion y en cada publicacion.
- Rango lat/lon [-90,90]/[-180,180].
- Rate limit 1s por conexion.
- SERENO solo publica unidad asignada.

## Tests
- Backend e2e: guard supabase (globalSetup) + suite existente 4a.
- Gateway: sin token, permisos por rol, sereno publicando su unidad, token vencido (pendientes de implementar).
- Flutter: analyze/test (pendiente de run real).

## Latencia
(pendiente de medicion real contra Render; completar con medir-latencia-ws.mjs)
- N enviados / recibidos / perdida: (pendiente)
- Mediana (ms): (pendiente)
- p95 (ms): (pendiente)
- Maximo (ms): (pendiente)
- Cold start Render: (pendiente)
