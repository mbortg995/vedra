# CLAUDE.md — Vedra

Contexto operativo para Claude Code. El README.md tiene la visión completa de
producto; este fichero es cómo trabajar en el repo. Ante conflicto, este manda
para decisiones técnicas y de estilo.

## Qué es Vedra

App móvil (Android + iOS) que responde a "¿Puedo hacer [actividad] en [punto GPS]
el [día]?" para actividades outdoor en España: pesca, recolección de setas, fuego
recreativo y caza. Cruza perfil + ubicación + fecha con normativa oficial y
devuelve un semáforo verde / amarillo / rojo, con la fuente oficial de cada regla.
Guarda licencias del usuario con vencimientos y avisa de vedas, cambios de riesgo
de incendio y caducidades. Mercado España, mantenedor único, modelo freemium con
suscripción anual barata.

## Regla de oro (NO NEGOCIABLE): ante la duda, rojo

La afirmación de mayor riesgo de la app es "puedes hacer fuego". Toda decisión de
diseño se inclina hacia el lado seguro:
- Toda regla lleva fuente oficial + fecha. La app siempre puede citarla. Nunca
  inventes ni deduzcas normativa; si no hay dato, no hay verde.
- Si un dato diario (preemergencia) falta o está caduco, el semáforo cae a ROJO.
  Nunca verde por omisión.
- Cuando varias reglas se solapan, gana SIEMPRE la más restrictiva.
- El pipeline de ingesta, ante cualquier anomalía de parseo, NO escribe. La
  ausencia de dato ya produce rojo.
- No añadas identificación de setas por foto. Fuera de alcance a propósito
  (riesgo de responsabilidad: un falso positivo puede matar).

Si una tarea te empuja a violar cualquiera de estos puntos, para y avísame antes
de seguir.

## Stack

- Backend: Supabase (PostgreSQL + PostGIS). Problema relacional-espacial.
- Móvil: Flutter (un código para Android + iOS, mapas offline).
- Suscripciones: RevenueCat (abstrae Google Play + App Store).
- Ingesta: Python + GitHub Actions (cron gratis). Claude API ayuda a parsear
  órdenes de veda en PDF a filas de REGLAS en borrador.
- Caché: Cloudflare delante de todo. Las respuestas son cacheables por
  `actividad:territorio_hoja:fecha` porque no dependen de quién pregunta (salvo
  el cruce de licencias, que se hace en cliente/capa fina). La viralidad escala
  una caché, no la base de datos.

## Modelo de datos (resumen; detalle en el ERD del proyecto)

- TERRITORIOS: árbol con geometría PostGIS (España → CCAA → provincia →
  zona/coto/área), vía `padre_id`. La consulta central es espacial:
  `ST_Contains(geom, punto)` subiendo por el árbol.
- REGLAS: tabla estrella. Campo `capa` (permanente/estacional/diaria) y `efecto`
  (requiere/prohibe/limita/condicional), con `parametros` jsonb, `vigencia`
  daterange, `fuente_id`, y `estado_revision` (borrador/revisada/publicada). Solo
  las `publicada` llegan al usuario.
- CONDICIONES_DIARIAS: única tabla con escrituras frecuentes (cron matinal).
  Campo `obtenido_en` implementa la política de frescura → rojo si caduco.
- Lado usuario pequeño: LICENCIAS_USUARIO (conectada a TIPOS_REQUISITO, el mismo
  catálogo que usan las reglas) y ZONAS_SEGUIDAS (alimenta notificaciones).

## Ficheros

- `README.md` — visión de producto y decisiones.
- `motor_evaluacion.md` — contrato del motor: entrada, salida, lógica del semáforo.
- `motor.py` — implementación de referencia (5 casos pasando). Capa de datos
  simulada con diccionarios; en producción son queries a Supabase. La lógica del
  semáforo NO cambia al conectar datos reales.
- `ingesta_preemergencia.py` — pipeline diario de preemergencia de la Comunitat
  Valenciana. `python3 ingesta_preemergencia.py --demo` lo ejecuta sin red.

## Contrato del motor (resumen)

Orden estricto de resolución; la primera regla que dispara manda:
1. Dato diario ausente/caduco en actividad que lo requiere → rojo.
2. Bloqueo activo (efecto `prohibe`, o preemergencia 3 sobre actividad afectada)
   → rojo.
3. Requisito `cumplido=false` (falta licencia, o sin sesión) → amarillo.
4. Todo cumplido y sin bloqueos → verde.
Preemergencia 3 afecta a fuego, acampada y setas (no solo al fuego).

## Convenciones de código

- Python: 3.x, biblioteca estándar siempre que se pueda; dependencias mínimas.
  El motor debe poder razonarse de un vistazo. Mantén los datos separados de la
  lógica (los diccionarios de `motor.py` se sustituyen por acceso a datos sin
  tocar el semáforo).
- Idioma: código y comentarios en español (dominio, nombres de tabla y campo en
  español). Nombres de funciones y variables en español coherentes con lo ya
  escrito.
- El pipeline de ingesta es defensivo por defecto: valida antes de escribir, y
  si algo huele raro, aborta sin escribir en vez de escribir un dato dudoso.
- SQL: usa PostGIS para lo espacial. Índices espaciales (GIST) sobre `geom`.
  Prefiere migraciones versionadas a cambios manuales en el panel.

## Estado y siguientes pasos

Entorno recién montado en Mac (antes se arrancó en Windows). Código en este repo
desde el día 1. Siguientes pasos previstos, en orden:
1. SQL real de creación de tablas con PostGIS e índices espaciales.
2. Crear proyecto Supabase y ejecutar ese SQL.
3. Datos semilla mínimos: Comunitat Valenciana + sus 7 zonas Previfoc, un par de
   actividades, unas reglas de ejemplo.
4. Reconectar `motor.py` para que lea de Supabase en vez de los diccionarios.
5. Afinar el parser de la GVA contra el HTML/API real (posible endpoint JSON
   interno en lugar de scraping de HTML).
6. Pantallas Flutter alrededor del semáforo: contextual "aquí y ahora" y cartera
   de licencias.
7. Flujo de curación asistida: PDF de veda → API de Claude → filas REGLAS en
   borrador → revisión manual → publicada.

## Fuentes de datos conocidas

- Preemergencia CV (7 zonas Previfoc, niveles 1/2/3, diario vía AEMET):
  https://prevencionincendiosgva.es/Meteorology/NivelPreemergencia
- Regla real ya identificada: prohibida la quema en terreno forestal y su zona de
  influencia entre el 1 de junio y el 15 de octubre, salvo plan local de quemas en
  zonas de bajo riesgo con preemergencia nivel 1 y hasta las 11:00 h máximo.

## Cómo interactuar conmigo (el mantenedor)

- Explícame las decisiones técnicas con su porqué, en español, sin dar por
  supuesto que domino todo el stack todavía.
- Antes de cambios grandes o irreversibles (borrar, reescribir migraciones,
  tocar credenciales), pregúntame.
- Nunca subas al repo secretos (claves de Supabase, tokens). Usa variables de
  entorno y `.env` en `.gitignore`.
