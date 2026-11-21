# Alerta Aguas Verdes — Contexto del proyecto para el agente

> Lee este archivo completo antes de tocar código. Describe qué estamos construyendo, qué requerimientos debemos cumplir, cómo debe funcionar el flujo SOS, en qué estado va el proyecto y cómo se trabaja.

---

## 1. Qué estamos desarrollando

**Proyecto académico:** "Modernización del sistema de alerta Aguas Verdes mediante la implementación de servicios en la nube y funcionalidades de monitoreo en tiempo real en la Municipalidad Distrital de Aguas Verdes, 2026".

- **Contexto:** prácticas preprofesionales II (UCV, Ingeniería de Sistemas) en la Oficina de Informática de la Municipalidad Distrital de Aguas Verdes (Tumbes).
- **Product Owner / jefe inmediato:** Ing. Jimmy Astor Florentino Ordinola Nima. **Supervisor UCV:** Aldo Segismundo Pereda Castillo.
- **Gestión:** PMI (5 grupos de procesos) + SCRUM, 6 sprints en 12 semanas.
- **Problema:** el serenazgo atiende emergencias con registros manuales, sin ubicación en tiempo real de las unidades, sin control de acceso por roles y sin indicadores para la gerencia. El sistema legado vivía en XAMPP (MySQL).
- **Alcance del informe:** solo software (backend, base de datos, nube, tiempo real). Excluye hardware e integración con la PNP.

### Stack

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Clean Architecture, BLoC) |
| Backend | NestJS en Render (`https://alerta-aguas-verdes-api.onrender.com`) |
| Base de datos | PostgreSQL + PostGIS en Supabase |
| Tiempo real | WebSockets (gateway NestJS) |
| Repositorio backend | `https://github.com/AngelDevEng/alerta-aguas-verdes` |

### Actores

| Rol | Autenticación | Qué hace |
|---|---|---|
| Ciudadano | Sin login | Consulta placas y conductor, ve accesos rápidos y mapa delictivo, reporta incidentes, pide auxilio (SOS) |
| Sereno | JWT | Accesos rápidos, mapa delictivo, atiende SOS |
| Operador | JWT | Gestiona alertas e incidencias, despacha unidades |
| Administrador | JWT | CRUD de todo; acepta o rechaza reportes ciudadanos |
| Directivo | JWT | Consulta indicadores y mapas de calor |

---

## 2. Sprints del plan (firmado el 20-sep-2026)

| Sprint | Historia | Contenido |
|---|---|---|
| 1 | H1 | BD relacional, índices, vistas, migración desde XAMPP, historial de estados |
| 2 | H2 | Datos geoespaciales `GEOGRAPHY(Point,4326)`, evidencias, unidades cercanas, posiciones GPS |
| 3 | H3 | Backend en la nube y API REST con Swagger |
| 4 | H4 | JWT, RBAC, endurecimiento de seguridad, protección de datos personales |
| 5 | H5 | WebSocket autenticado, ubicación en vivo, alertas SOS inmediatas, mapa en vivo |
| 6 | H6 | Indicadores, mapa de calor, dashboard directivo, pruebas y documentación final |

El informe PPP II (portada: diciembre 2026) detalla Fases 1-2 y Sprints 1-3, pero ya describe H4-H6 y afirma resultados en las conclusiones. **Esas afirmaciones deben poder demostrarse** (ver sección 8).

---

## 3. Requerimientos

### 3.1 Funcionales oficiales (del informe)

| ID | Requerimiento | Sprint |
|---|---|---|
| RF01 | Registrar incidencia con tipo, descripción, prioridad y coordenadas | 1-3 |
| RF02 | Adjuntar evidencias multimedia (foto, video) con su ubicación | 2-3 |
| RF03 | Consultar y filtrar incidencias por estado, tipo y fechas, con paginación | 3 |
| RF04 | Registrar y consultar unidades de serenazgo y su estado operativo | 3 |
| RF05 | Despachar una unidad disponible a una incidencia | 3 |
| RF06 | Consultar unidades disponibles más cercanas a un punto | 2-3 |
| RF07 | Historial de cambios de estado de cada incidencia | 1-2 |
| RF08 | Autenticación JWT y control de acceso por roles (RBAC) | 4 |
| RF09 | Transmitir y visualizar la ubicación de unidades en tiempo real | 5 |
| RF10 | Indicadores estadísticos y mapas de calor delictivo | 6 |

### 3.2 Funcionales propuestos (ampliación, pendiente de registrar en el Product Backlog con el PO)

| ID | Requerimiento | Relación |
|---|---|---|
| RF11 | Consulta pública de placa y datos del conductor | Nueva |
| RF12 | Accesos rápidos de emergencia: lectura pública, CRUD solo admin | Nueva |
| RF13 | Reporte ciudadano de incidente; el admin lo acepta o rechaza | Extiende RF01 |
| RF14 | Mapa delictivo público, solo con incidentes aceptados | Extiende RF10 |
| RF15 | SOS ciudadano sin login: crear, esperar y cancelar | Extiende HU5.3 |
| RF16 | Aceptación exclusiva de la alerta por un sereno | Nueva |
| RF17 | Seguimiento mutuo ciudadano-sereno solo después de aceptar | Extiende RF09 |
| RF18 | Gestión de alertas: historial, escalamiento y expiración | Nueva |

### 3.3 No funcionales

| ID | Requerimiento | Cómo se atiende |
|---|---|---|
| RNF01 | Disponibilidad y escalabilidad | Render + Supabase; el servicio **no debe suspenderse por inactividad** |
| RNF02 | Seguridad | SSL a la BD, secretos en variables de entorno, consultas parametrizadas, validación de entradas, Helmet |
| RNF03 | Integridad de datos | PK/FK, CHECK, UNIQUE, enums |
| RNF04 | Rendimiento espacial | Índices GiST |
| RNF05 | Interoperabilidad | API REST JSON documentada en Swagger (incluir endpoints nuevos) |
| RNF06 | Protección de datos personales | Ley N.° 29733, acceso por roles |
| RNF07 | Mantenibilidad | NestJS modular, scripts SQL versionados |
| RNF08 *(propuesto)* | Privacidad de la ubicación del ciudadano | Se comparte solo con el sereno asignado; retención de 30 días; consulta solo admin |
| RNF09 *(propuesto)* | Resistencia a abuso | Rate limiting, una SOS activa por dispositivo |
| RNF10 | Latencia menor a 2 s (criterio de H5) | Debe **medirse** y documentarse |
| RNF11 | Pruebas automatizadas de flujos críticos | Aceptación concurrente, autorización, transiciones inválidas |

---

## 4. Flujo SOS objetivo

1. El ciudadano (sin login) presiona SOS. Se crea la alerta con su ubicación y recibe un **token de sesión anónimo**.
2. Ve el mapa en tiempo real en modo "esperando sereno". Mientras espera, solo comparte su ubicación con el servidor.
3. Los serenos conectados reciben la alerta por WebSocket al instante y la ven con su última ubicación conocida.
4. Un sereno acepta mediante un endpoint dedicado y **atómico**. Si otro ya la aceptó, recibe 409.
5. **Solo al aceptar** se activa el seguimiento mutuo: el ciudadano ve al patrullero y el patrullero ve al ciudadano.
6. El cierre corta el seguimiento, libera **únicamente** la unidad asignada y conserva el historial.

### 4.1 Máquina de estados de `alertas.estado`

```
ACTIVA --(POST /aceptar, solo SERENO)--> ACEPTADA --(sereno cierra)--> ATENDIDA
  |                                          |--(sereno que aceptó)--> FALSA
  |--(ciudadano cancela)--> CANCELADA        |--(ciudadano cancela)--> CANCELADA
  |--(cron)--> EXPIRADA                      |--(cron)--> EXPIRADA
```

- Estados: `ACTIVA`, `ACEPTADA`, `ATENDIDA`, `CANCELADA`, `FALSA`, `EXPIRADA`. Los cuatro últimos son terminales.
- `ACTIVA → ACEPTADA` solo por `POST /alertas/:id/aceptar`. `PATCH /alertas/:id/estado` **no** acepta `ACEPTADA`.
- Nadie cierra una alerta sin haberla aceptado, salvo ADMIN.
- Pueden cerrar una alerta aceptada: quien la aceptó, el responsable de `unidad_id`, o ADMIN.
- Toda transición usa `SELECT ... FOR UPDATE` o `UPDATE ... WHERE estado = <esperado>` y verifica `rowCount`.
- `liberar` devuelve la alerta a `ACTIVA`, la incidencia a `REGISTRADA`, pone `unidad_asignada_id = NULL`, limpia `aceptada_*`, `unidad_id` y `escalada_en`, y reinicia `expira_en = now() + 20 min`.
- El enum `estado_incidencia` es `REGISTRADA, DESPACHADA, EN_ATENCION, ATENDIDA, CANCELADA`. **No se le agregan estados.** `ACTIVA` no existe como estado de incidencia.

### 4.2 Columnas nuevas en `alertas`

`aceptada_por`, `aceptada_en`, `unidad_id`, `dispositivo_id`, `escalada_en`, `expira_en` (`DEFAULT now() + interval '20 minutes'`; un DEFAULT no puede referenciar otra columna).

### 4.3 Tablas nuevas

- `sessions_anonimas`: `id`, `alerta_id`, `token_hash` (SHA-256), `dispositivo_id`, `ip`, `creado_en`, `expira_en`, `revocado`.
- `ubicaciones_ciudadano`: `id`, `alerta_id`, `ubicacion` (geography), `velocidad_kmh`, `registrado_en`.
- Ambas con **RLS activado sin políticas**.
- Índice único parcial: una sola alerta `ACTIVA`/`ACEPTADA` por `dispositivo_id`.

### 4.4 Endpoints

| Endpoint | Acceso | Notas |
|---|---|---|
| `POST /api/v1/alertas` | Público + `X-Device-Id` | Conserva los campos actuales de la respuesta y añade `sessionToken`. Si el dispositivo ya tiene alerta viva, devuelve esa con un token nuevo |
| `GET /api/v1/alertas/:id/seguimiento` | `X-Session-Token` o JWT del sereno asignado | Estado actual y últimas posiciones; sirve para reconexión |
| `POST /api/v1/alertas/:id/aceptar` | SERENO (sin cuerpo) u OPERADOR/ADMIN (`{ unidadId }`) | Transacción; responde `{ alerta, ciudadano: { ubicaciones } }`; 409 si ya fue tomada, si no hay unidad o si está `OCUPADA` |
| `POST /api/v1/alertas/:id/liberar` | Sereno que aceptó o ADMIN | Ver 4.1 |
| `POST /api/v1/alertas/:id/cancelar` | `X-Session-Token` | En `ACTIVA` y `ACEPTADA`; notifica al sereno y libera su unidad |
| `PATCH /api/v1/alertas/:id/estado` | JWT | Valida la máquina de estados; nunca `ACEPTADA` |
| `POST /api/v1/alertas/:id/posicion` | `X-Session-Token` | Rechaza alertas terminales, valida rangos, mínimo 3 s entre envíos |
| `POST /api/v1/unidades/:id/ubicaciones` | JWT | Debe validar que la unidad pertenece al sereno autenticado y resolver su alerta activa |

`PATCH /incidencias/:id/asignar` responde **409** si la incidencia proviene de una SOS `ACTIVA` o `ACEPTADA`: el despacho de SOS vive solo en `/aceptar`.

### 4.5 Eventos WebSocket

- `nueva_alerta_sos` → salas `central` y `serenos`, al crear (usar `to(['central','serenos'])` para no duplicar).
- `alerta_aceptada`, `alerta_liberada`, `alerta_cerrada` → sala `sos:{alertaId}`.
- `posicion_unidad`, `posicion_ciudadano` → sala `sos:{alertaId}`, **solo tras aceptar**.

### 4.6 Autorización y privacidad

- Token anónimo: `crypto.randomBytes(32)`, se guarda solo el hash, se compara con `timingSafeEqual`, viaja en el **cuerpo JSON** al crear y luego en el header `X-Session-Token`. Nunca en query string.
- Vigencia: 12-24 h al crear; al cerrar la alerta se acorta a 10 min y sirve **solo** para `GET /seguimiento`.
- Sala `sos:{alertaId}`: entran solo el ciudadano dueño (token) y el sereno asignado (JWT, y `unidad.responsable_id` = su usuario). El ciudadano se une al crear, solo para recibir eventos de estado; las posiciones se emiten únicamente tras aceptar.
- Los serenos ven la **última ubicación conocida** del ciudadano en la lista de alertas pendientes (**decisión pendiente de confirmar por el usuario**). La transmisión en vivo empieza al aceptar.
- `dispositivo_id` es secreto: UUID de alta entropía, fuera de logs y de respuestas.
- Un SERENO acepta con su propia unidad (`unidades_serenazgo.responsable_id`); nunca envía `unidadId`. Si tiene varias unidades, 409 y pide ayuda al operador.
- Rate limiting: `POST /alertas` 3 por 10 min por dispositivo y 10 por 10 min por IP. Configurar `trust proxy` (Render) para ver la IP real.
- `ubicaciones_ciudadano`: retención 30 días, consulta solo ADMIN.

### 4.7 Robustez

- Cron de escalado: `creada_en < now() - interval '2 minutes' AND escalada_en IS NULL`, con `RETURNING id` para notificar solo esas filas.
- Cron de expiración: `UPDATE ... SET estado='EXPIRADA' WHERE estado='ACTIVA' AND expira_en < now()`.
- Alerta `ACEPTADA` sin ubicación del sereno por X minutos: avisar al admin y permitir reasignar.
- Al expirar, el ciudadano ve los accesos rápidos de emergencia.
- Reconexión: `GET /seguimiento` más re-suscripción del socket.
- Flutter: servicio en segundo plano para sereno y ciudadano; el token anónimo y el `alertaId` van en almacenamiento seguro **separado** de `TokenStore`.

---

## 5. Hallazgos de la auditoría del código (estado real)

- `POST /alertas` es público y crea `incidencias` (tipo `EMER`, prioridad `CRITICA`) y `alertas` en una transacción. No hay rate limiting ni identificador de ciudadano.
- `RealtimeService.notificarNuevaAlerta()` existe pero `AlertasService.crear()` **nunca la llama**. El dashboard del patrullero usa polling.
- No existe endpoint para aceptar una alerta. `PATCH /alertas/:id/estado` no bloquea doble aceptación.
- No hay salas por alerta. Solo `central`, `serenos` y `user:${id}`.
- El ciudadano no puede seguir su alerta: `GET /alertas/:id` exige JWT y da 401 sin sesión. No envía ubicación después del SOS inicial.
- `PATCH /incidencias/:id/asignar` es atómico (`FOR UPDATE`) pero solo OPERADOR/ADMIN.
- Al cerrar, la liberación de unidad filtra por el ID de la unidad asignada (`alertas.service.ts:88-89`, `incidencias.service.ts:87-92`). No hay bug.
- Los IDs de alerta son UUID. No hay RLS en ningún script de `database/`.

---

## 6. Estado del proyecto y lo que falta

| Requerimiento | Estado |
|---|---|
| RF01-RF07 (H1-H3) | Documentado en el informe; no re-verificado |
| RF08 (H4) | Casi: falta validar propiedad de unidad en ubicaciones |
| RF09 (H5) | Parcial: gateway existe, pero crear SOS no emite y hay polling |
| RF10 (H6) | Sin verificar |
| RF11-RF14 | Sin auditar |
| RF15-RF18 | Falta lo central (plan de fases) |
| RNF01 | Confirmar que Render no se duerme |
| RNF02 | Falta rate limiting y RLS |

### Plan de implementación (una fase a la vez)

0. Verificación (sin cambios de código).
1. Migración, token anónimo, `GET /seguimiento`, notificación WebSocket al crear, una SOS por dispositivo. Flutter: guardar sesión y navegar al rastreo.
2. `POST /aceptar` atómico y `POST /liberar`. Flutter: botones Aceptar/Liberar.
3. Sala `sos:{alertaId}` y autorización en el gateway.
4. Seguimiento mutuo y servicio en segundo plano.
5. Cron de escalado y expiración, rate limiting, accesos rápidos al expirar.
6. Cancelación por el ciudadano y cierre.

Cada fase incluye su parte Flutter y una prueba automatizada de lo crítico (aceptación concurrente por dos serenos, acceso denegado a la sala, transiciones inválidas).

### Después del flujo SOS

1. Auditar H6, reportes de incidentes, mapa delictivo, placas, conductor y accesos rápidos.
2. Seguridad mínima: RLS, rate limiting, `trust proxy`, Render siempre activo.
3. Evidencia para el informe: medición de latencia, resultados de pruebas, capturas, Swagger actualizado.
4. Actualizar el informe (sección 8).
5. Cierre: validación con el PO, acta de conformidad, manual breve y lecciones aprendidas.

---

## 7. Reglas de trabajo para el agente

1. **Una fase a la vez.** Implementa solo la fase autorizada, muestra el diff y espera confirmación antes de seguir.
2. **No inventes.** Si algo no existe o no puedes verificarlo, dilo. Cita siempre archivo y función.
3. **Migraciones:** transaccionales e idempotentes. Muestra el SQL final **antes** de aplicarlo en Supabase. El backend no ejecuta migraciones.
4. **Orden de despliegue:** respaldo en Supabase, migración, backend, app. Al revés rompería `POST /alertas`.
5. **Compatibilidad:** las respuestas existentes solo se **amplían**. La app instalada debe seguir funcionando.
6. **RLS:** confirma con qué rol conecta el backend. Si es el dueño de las tablas, activa RLS sin políticas en todas las tablas públicas (el dueño ignora RLS; lo que se bloquea es la API pública de Supabase con clave `anon`). Si no es el dueño, avisa antes de activar nada.
7. **Verifica antes de afirmar.** Nombres de columnas, constraints, tipos de enum y dependencias de vistas (`v_alertas_activas` depende de `alertas.estado`: no cambies el tipo sin recrear la vista).
8. **Seguridad:** nunca registres tokens ni `dispositivo_id` en logs; no los devuelvas en respuestas posteriores.
9. **Swagger:** documenta todo endpoint nuevo.
10. **No reutilices** `atendida_por`/`atendida_en` para la aceptación.

---

## 8. Informe PPP II: qué debe quedar respaldado

El informe afirma lo siguiente; cada punto necesita evidencia o una redacción más prudente:

- Latencia menor a 2 s en el rastreo y recepción de alertas (medir y documentar).
- Difusión instantánea de alertas SOS a los operadores (hoy `crear()` no emite; se corrige en la Fase 1).
- "Panel web de la central" (HU5.4): confirmar si existe; hoy lo auditado es una app Flutter.
- Mapa de calor con PostGIS e indicadores por tipo, zona y período.
- Cifrado y restricción de visibilidad de datos de denunciantes (HU4.4).
- Pruebas unitarias y de integración, y documentación Swagger.
- Tabla de endpoints incompleta (faltan alertas, autenticación, usuarios y los nuevos del flujo SOS).
- Anexos: agregar capturas, diagrama de estados del SOS, matriz de trazabilidad y resultados de pruebas.
- Conclusión del OE1: hoy dice "10 RF y 7 RNF"; actualizar si se amplían.
- Fase 5 (cierre): acta de conformidad, manual breve, lecciones aprendidas y presentación final.

---

## 9. Tareas de verificación inmediata (sin cambiar código)

1. Matriz de trazabilidad: requerimiento → HU → sprint → módulo → estado (Cumplido / Parcial / No implementado / No verificable) con archivo y función como evidencia.
2. Verificar una por una las afirmaciones de la sección 8 contra el código.
3. Auditar placas, conductor, accesos rápidos, reportes de incidentes, mapa delictivo y dashboards.
4. Confirmar: rol de BD con el que conecta el backend, plan de Render (si se duerme), salas `central` y `serenos` y quién se une a cada una, y el tipo real de `alertas.estado`.
5. Entregar lista priorizada de lo que falta, con esfuerzo (pequeño/mediano/grande), considerando que el informe se entrega en diciembre de 2026.
