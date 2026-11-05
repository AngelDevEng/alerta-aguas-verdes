# Medicion de latencia (Sprint 5)

La latencia se mide con el reloj del servidor, no con relojes de clientes distintos.
- Cada evento emitido incluye `serverTime` (ISO) generado en el backend.
- Round-trip: el cliente envia `ping_latencia` con `t = Date.now()` (informativo); el
  servidor responde `pong_latencia` con `serverTime` y `rtt = serverTime - t` calculado
  en el servidor. El cliente NO compara relojes propios entre dispositivos.
- Para mediciones entre dispositivos, usar solo `serverTime` del servidor como referencia.

## Arranque en frio de Render
Render puede suspender el servicio por inactividad. El primer request tras la suspension
incurrira en latencia de arranque (cold start) de varios segundos. Medir latencia
excluyendo el primer request post-suspension, o mantener el servicio activo (plan de pago)
para evitar suspension.
