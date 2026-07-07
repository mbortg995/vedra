# Vedra

App móvil (Android + iOS) que responde a una pregunta: **"¿Puedo hacer esto,
aquí, hoy?"** para actividades outdoor en España — pesca, recolección de setas,
uso de fuego recreativo y caza. Cruza tu perfil, tu ubicación (GPS) y la fecha
con la normativa oficial y te devuelve un semáforo: verde / amarillo / rojo, con
la fuente oficial de cada regla.

Guarda además tus licencias con sus vencimientos y te avisa de aperturas de
veda, cambios de nivel de riesgo de incendio y caducidades.

---

## Por qué este nicho

- No es un mercado saturado: la normativa outdoor española está dispersa entre
  el Estado, 17 CCAA y ayuntamientos, y nadie la ha unificado bien en móvil.
- Audiencia apasionada y pagadora (perfil Wikiloc), con fuerte solapamiento
  entre pescadores, cazadores y recolectores de setas. Suele tener +35 años, así
  que la interfaz prioriza legibilidad y claridad.
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
- Toda regla lleva su fuente oficial y su fecha; la app siempre puede citarla, y
  guarda incluso la cita textual de la norma.
- Si el dato diario falta o está caduco, el semáforo cae a rojo. Nunca verde
  por omisión.
- Cuando varias reglas se solapan, gana la más restrictiva.
- El pipeline de ingesta, ante cualquier anomalía de parseo, NO escribe. La
  ausencia de dato ya produce rojo, que es el comportamiento seguro.
- Solo la normativa **revisada por un humano y publicada** llega al usuario;
  nada se publica automáticamente.

---

## Stack

| Pieza | Elección | Motivo |
|-------|----------|--------|
| Backend | **Supabase** (PostgreSQL + PostGIS) | El producto es un problema relacional-espacial. Postgres gestionado, RLS, auth y API REST resueltos, menos piezas para un mantenedor único. |
| Móvil | **Flutter** | Un código para Android + iOS, buen soporte de mapas offline, menos sorpresas en solitario. |
| Suscripciones | **RevenueCat** | Abstrae Google Play + App Store, gestiona renovaciones y churn. |
| Ingesta y curación | **Python (solo stdlib) + GitHub Actions** | Cron gratis con logs para el dato diario. La curación de normativa (PDF/orden → reglas) la hace **Claude Code** (sesión o tarea programada sobre el plan de Claude), no una API de pago. |
| Caché (previsto) | **Cloudflare** delante de todo | Las respuestas son idénticas para todos (salvo licencias), así que un pico viral se sirve desde CDN, no toca la base de datos. |

Clave de escalado: la respuesta a "¿puedo pescar aquí hoy?" no depende de quién
pregunta, así que es cacheable por `actividad:territorio_hoja:fecha`. La
viralidad escala una caché, no la base de datos. *(La lógica del semáforo corre
hoy en el cliente de forma interina; el diseño final la mueve a una Edge Function
de Supabase cacheable en CDN.)*

## Modelo de datos (resumen)

Árbol de **TERRITORIOS** con geometría PostGIS (España → CCAA → provincia →
zona/coto/área), con un `codigo` estable por territorio. La consulta central es
espacial (`ST_Contains`), expuesta a la app como la RPC `territorios_en_punto`.

La tabla estrella **REGLAS** unifica tres capas en el campo `capa`:
- **permanente**: licencias, zonas, límites fijos.
- **estacional**: vedas, épocas de peligro de incendio.
- **diaria**: preemergencia (única tabla con escrituras frecuentes, en
  CONDICIONES_DIARIAS, con marca de frescura).

Cada regla lleva `efecto` (requiere/prohibe/limita/condicional), `fuente`, `cita`
textual y `estado_revision` (borrador → revisada → publicada). **Row Level
Security** garantiza que solo las reglas `publicada` son públicas, y que los
datos de usuario (LICENCIAS_USUARIO, ZONAS_SEGUIDAS) solo los ve su dueño.

## Estado actual

Backend **completo y con datos reales**; primera pantalla de la app funcionando:
- Esquema PostGIS + índices espaciales; RLS; RPC espacial (migraciones versionadas).
- Comunitat Valenciana con geometría **oficial** (IGN); 7 zonas Previfoc
  provisionales (pendiente la geometría oficial).
- **Ingesta diaria** del nivel de preemergencia de la CV (GitHub Action, cron).
- **Curación asistida** de normativa (pesca y quema ya publicadas) + **vigilancia**
  semanal de fuentes que avisa por issue cuando una norma cambia.
- App **Flutter**: pantalla del semáforo "aquí y ahora" leyendo de Supabase.

El backlog hacia el MVP vive en **GitHub Issues** (milestones `MVP` / `Post-MVP`,
labels por área). Vista de un vistazo en el issue-checklist "🎯 MVP".

## Estructura del repositorio

- `motor_evaluacion.md` — contrato del motor: entrada, salida y orden del semáforo.
- `motor.py` — implementación de referencia del semáforo (5 casos). Recibe un
  proveedor de datos; la lógica no cambia según la fuente.
- `datos.py` — capa de acceso con dos proveedores: `DatosMemoria` (tests) y
  `DatosSupabase` (REST/PostgREST, solo stdlib).
- `validar_supabase.py` — evaluación en vivo del motor contra Supabase.
- `ingesta_preemergencia.py` — pipeline diario de preemergencia CV (`--demo` sin red).
- `curacion.py` + `curacion.md` — curación asistida: JSON de reglas → borrador →
  revisión humana → publicada. `curacion/` guarda los artefactos y las fuentes vigiladas.
- `vigilancia_fuentes.py` — detección de cambios en documentos oficiales (por hash).
- `supabase/migrations/` — esquema y datos semilla como migraciones versionadas.
- `.github/workflows/` — cron de ingesta y de vigilancia.
- `app/` — aplicación Flutter (web/iOS/Android).
- `.env.example` — plantilla de variables de entorno (secretos en `.env`, gitignored).

## Cómo ejecutar

```bash
python3 motor.py                         # 5 casos del semáforo (sin red)
python3 validar_supabase.py              # evaluación en vivo (usa .env)
python3 ingesta_preemergencia.py --demo  # ingesta sin red
python3 curacion.py listar               # curación: listar/insertar/publicar reglas
supabase db push                         # aplicar migraciones al proyecto
cd app && flutter run                    # app (o `flutter run -d chrome`)
```

Los secretos (URL y claves de Supabase, etc.) van en `.env`; ver `.env.example`.
