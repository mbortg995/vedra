# Contrato del motor de evaluación

El motor responde a una sola pregunta: **"¿Puedo hacer [actividad] en [punto GPS] el [día]?"**
Devuelve siempre un objeto con un semáforo (`verde` / `amarillo` / `rojo`), la lista de
requisitos y sus fuentes. La app nunca inventa: cada afirmación cuelga de una fila de la base
de datos con su fuente oficial y su fecha.

---

## 1. Entrada (request)

```json
{
  "actividad": "fuego_recreativo",          // slug de ACTIVIDADES
  "lat": 39.9864,
  "lon": -0.0513,
  "fecha": "2026-07-06",                     // ISO, por defecto hoy
  "usuario_id": "uuid-o-null"                // null si no hay sesión: no se cruzan licencias
}
```

## 2. Salida (response)

```json
{
  "semaforo": "amarillo",
  "titulo": "Puedes, pero te falta algo",
  "actividad": "fuego_recreativo",
  "territorios": [                            // cadena que contiene el punto, de mayor a menor
    { "id": "...", "nivel": "ccaa",      "nombre": "Comunitat Valenciana" },
    { "id": "...", "nivel": "zona_pref", "nombre": "Zona 4 - Interior Norte de Castelló" },
    { "id": "...", "nivel": "area",      "nombre": "Àrea recreativa Sant Joan de Penyagolosa" }
  ],
  "requisitos": [                            // lo que el usuario DEBE tener/cumplir
    {
      "tipo": "usar_paellero_habilitado",
      "cumplido": true,
      "detalle": "Solo en paelleros de áreas recreativas habilitadas.",
      "fuente": { "organismo": "GVA - Prevención Incendios", "fecha": "2026-06-01", "url": "https://..." }
    },
    {
      "tipo": "licencia_o_permiso",
      "cumplido": false,                     // el usuario no la tiene registrada -> pinta amarillo
      "detalle": "No aplica permiso para esta área.",
      "fuente": null
    }
  ],
  "bloqueos": [],                            // reglas 'prohibe' activas -> si hay alguna, rojo
  "condiciones_dia": [                       // capa diaria que se ha cruzado
    {
      "tipo": "preemergencia_incendios",
      "nivel": "1",
      "obtenido_en": "2026-07-06T07:12:00Z",
      "fresco": true,                        // false -> el motor degrada a rojo por seguridad
      "fuente": { "organismo": "GVA / AEMET", "url": "https://prevencionincendiosgva.es/..." }
    }
  ],
  "avisos": [                                // texto libre para pintar en pantalla
    "Uso de fuego permitido solo hasta las 11:00 h en día de preemergencia nivel 1."
  ],
  "generado_en": "2026-07-06T07:15:22Z",
  "disclaimer": "Información orientativa. Consulta siempre la fuente oficial antes de actuar."
}
```

---

## 3. Lógica de resolución (orden estricto)

El semáforo se calcula recorriendo estas reglas **en orden**. La primera que dispara, manda.
Principio rector: **ante la duda, más restrictivo**.

1. **Dato diario ausente o caduco** en una actividad que depende de condición diaria
   (`fuego_recreativo`, y en preemergencia 3 también `acampada`/`setas`).
   -> `rojo`. Nunca se asume "verde" por falta de dato.

2. **Algún `bloqueo` activo** (regla con `efecto = "prohibe"` vigente hoy en algún territorio
   de la cadena, o condición diaria que prohíbe: p.ej. preemergencia 3 sobre fuego).
   -> `rojo`.

3. **Algún requisito `cumplido = false`** (falta licencia/permiso, o el usuario no ha iniciado
   sesión y la actividad exige licencia).
   -> `amarillo`.

4. **Todo cumplido y sin bloqueos.**
   -> `verde`.

Regla transversal: cuando varias reglas del mismo tipo aplican por solaparse territorios
(p.ej. límite de 6 kg de la CCAA y de 3 kg del coto), **gana el valor más restrictivo**.

---

## 4. Por qué este contrato escala

- La respuesta depende solo de (actividad, territorio, fecha) para todo lo que no sean
  licencias. Eso significa que es **cacheable en CDN** con clave
  `actividad:territorio_hoja:fecha` y TTL hasta la próxima actualización diaria.
- El cruce con las licencias del usuario (`cumplido: true/false`) se hace en cliente o en una
  capa fina, sobre la respuesta ya cacheada. La parte cara (resolver territorios + reglas)
  se sirve idéntica a todo el mundo.
- Añadir un vertical nuevo no cambia el contrato: solo añade filas en ACTIVIDADES y REGLAS.
