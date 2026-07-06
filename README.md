# Vedra

App móvil (Android + iOS) que responde a una pregunta: **"¿Puedo hacer esto,
aquí, hoy?"** para actividades outdoor en España — pesca, recolección de setas,
uso de fuego recreativo y caza. Cruza tu perfil, tu ubicación (GPS) y la fecha
con la normativa oficial y te devuelve un semáforo: verde / amarillo / rojo.

Guarda además tus licencias con sus vencimientos y te avisa de aperturas de
veda, cambios de nivel de riesgo de incendio y caducidades.

---

## Por qué este nicho

- No es un mercado saturado: la normativa outdoor española está dispersa entre
  el Estado, 17 CCAA y ayuntamientos, y nadie la ha unificado bien en móvil.
- Audiencia apasionada y pagadora (perfil Wikiloc), con fuerte solapamiento
  entre pescadores, cazadores y recolectores de setas.
- Ser específicamente español es la ventaja competitiva, no una limitación:
  los gigantes globales no entran en la regulación por comunidad autónoma.

## Modelo de negocio

Freemium con suscripción anual barata (~12-15 €/año, cobrada anual para
coincidir con el ciclo de renovación de licencias).

- **Gratis**: consultar una actividad en tu comunidad, guardar una licencia.
- **Premium**: multi-actividad, multi-comunidad, alertas de vedas y
  vencimientos, y el botón contextual GPS "aquí y ahora".

## Alcance del MVP

Lanzar con:
- **Pesca** y **setas** (comparten fuentes de datos y audiencia; licencias
  obligatorias con renovación anual = dolor recurrente ideal para suscripción).
- **Capa de fuego** (nivel de preemergencia diario) en la Comunitat Valenciana
  primero — terreno propio, validable en persona.

Segundo release:
- **Caza** (comparte datos con pesca, añade complejidad de cotos y planes
  cinegéticos que no hacen falta para validar el concepto).
- Ampliación de la capa de fuego a más CCAA donde el dato diario sea fiable.

Fuera del MVP a propósito:
- **Identificación de setas por foto**: campo de minas de responsabilidad
  (un falso positivo puede matar). Vedra va de *dónde y cuánto puedes recoger*,
  no de *qué es esto*.

## Principio rector de seguridad

**Ante la duda, rojo.** La afirmación de más riesgo de la app es "puedes hacer
fuego". Por eso:
- Toda regla lleva su fuente oficial y su fecha; la app siempre puede citarla.
- Si el dato diario falta o está caduco, el semáforo cae a rojo. Nunca verde
  por omisión.
- Cuando varias reglas se solapan, gana la más restrictiva.
- El pipeline de ingesta, ante cualquier anomalía de parseo, NO escribe. La
  ausencia de dato ya produce rojo, que es el comportamiento seguro.

---

## Stack

| Pieza | Elección | Motivo |
|-------|----------|--------|
| Backend | **Supabase** (PostgreSQL + PostGIS) | El producto es un problema relacional-espacial. Postgres gestionado, auth y API resueltos, menos piezas para un mantenedor único. |
| Móvil | **Flutter** | Un código para Android + iOS, buen soporte de mapas offline, menos sorpresas en solitario. |
| Suscripciones | **RevenueCat** | Abstrae Google Play + App Store, gestiona renovaciones y churn. Gratis hasta 2.500 $/mes. |
| Ingesta de datos | **Python + GitHub Actions** | Cron gratis con logs. Claude vía API ayuda a parsear órdenes de veda en PDF a filas de REGLAS en borrador. |
| Caché | **Cloudflare** delante de todo | Las respuestas son idénticas para todos los usuarios (salvo licencias). Un pico viral se sirve desde CDN, no toca la base de datos. |

Clave de escalado: la respuesta a "¿puedo pescar aquí hoy?" no depende de quién
pregunta, así que es cacheable por `actividad:territorio_hoja:fecha`. La
viralidad escala una caché, no la base de datos.

## Modelo de datos (resumen)

Árbol de **TERRITORIOS** con geometría PostGIS (España → CCAA → provincia →
zona/coto/área). La tabla estrella **REGLAS** unifica tres capas en el campo
`capa`:
- **permanente**: licencias, zonas, límites fijos.
- **estacional**: vedas, épocas de peligro de incendio.
- **diaria**: preemergencia, cierres puntuales (única tabla con escrituras
  frecuentes, en CONDICIONES_DIARIAS).

El lado usuario es pequeño: LICENCIAS_USUARIO (con vencimientos, conectado al
mismo catálogo TIPOS_REQUISITO que usan las reglas) y ZONAS_SEGUIDAS (alimenta
las notificaciones).

## Ficheros en este proyecto

- `motor_evaluacion.md` — contrato del motor: entrada, salida y lógica del
  semáforo.
- `motor.py` — implementación de referencia del motor (5 casos de prueba
  pasando). La capa de datos está simulada; en producción son queries a
  Supabase, la lógica del semáforo no cambia.
- `ingesta_preemergencia.py` — pipeline diario de nivel de preemergencia de la
  Comunitat Valenciana. Ejecuta con `--demo` para verlo sin red.

---

## Siguientes pasos

1. Montar repositorio Git (GitHub) — el código vive ahí desde el día 1.
2. Comprobaciones de nombre: dominio `.es`/`.app`, marca en OEPM (Vedra).
3. SQL real de creación de tablas con PostGIS e índices espaciales.
4. Afinar el parser de la GVA contra el HTML/API real (posible endpoint JSON
   interno en vez de scraping de HTML).
5. Pantallas Flutter alrededor del semáforo: la contextual "aquí y ahora" y la
   cartera de licencias.
6. Flujo de curación asistida: orden de vedas en PDF → API de Claude → filas de
   REGLAS en borrador → revisión manual → publicada.

## Nota de continuidad

Trabajo arrancado en Windows, desarrollo real en Mac. El contexto completo de
decisiones está en la conversación añadida a este proyecto. Al retomar desde el
Mac: los ficheros están aquí y el código irá en el repo Git.
