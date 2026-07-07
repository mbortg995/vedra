# Curación asistida de normativa

Convierte un documento oficial (orden de veda, decreto forestal, etc.) en filas de
`REGLAS` **en borrador**, para que el mantenedor las revise y publique. El paso de
interpretación lo hace **Claude Code** (esta sesión o, en la Fase 7b, una routine
programada sobre el plan de Claude), no una API de pago.

## Flujo

1. **Fuente** — se parte de un documento oficial (PDF/DOGV) con su URL.
2. **Extracción (Claude)** — Claude lee el documento y produce un JSON de reglas
   (esquema abajo), cada una con su `cita` textual y su `fuente`.
3. **Inserción** — `python3 curacion.py insertar reglas.json` → todas entran como
   `estado_revision = 'borrador'`. Nunca se publica en este paso.
4. **Revisión (humano)** — el mantenedor lista y comprueba fidelidad a la fuente:
   `python3 curacion.py listar --estado borrador`
   `python3 curacion.py revisar <id>`   (borrador → revisada)
5. **Publicación (humano)** — solo tras revisar:
   `python3 curacion.py publicar <id>`  (revisada → publicada; exige 'revisada')
   Descartar un borrador erróneo: `python3 curacion.py rechazar <id>`.

**Regla de oro:** la extracción automática solo genera borradores. El salto a
`publicada` es SIEMPRE una acción humana; el script no lo permite sin pasar por
`revisada`. Nunca se inventa ni se deduce normativa: si el documento no lo dice
con claridad, no se crea la regla.

## Esquema del JSON

Lista de objetos regla:

```json
[
  {
    "territorio_codigo": "CV",                 // codigo de TERRITORIOS
    "actividad_slug": "pesca",                 // slug de ACTIVIDADES
    "fuente": {                                // se reutiliza por url si ya existe
      "organismo": "GVA - Conselleria de Agricultura",
      "url": "https://dogv.gva.es/...",
      "fecha_publicacion": "2016-10-31"
    },
    "capa": "estacional",                      // permanente | estacional | diaria
    "efecto": "limita",                        // requiere | prohibe | limita | condicional
    "parametros": { "talla_min_cm": 25, "especie": "anguila" },
    "vigencia": ["2016-11-01", "2017-10-31"],  // [desde, hasta) o null si permanente
    "detalle": "Talla mínima de la anguila: 25 cm.",   // texto para el usuario
    "cita": "Art. X: La talla mínima de la anguila será de 25 cm.",  // literal de la norma
    "requisitos": ["licencia_pesca_cv"]        // opcional, para efecto=requiere
  }
]
```

`parametros` es libre (jsonb): `talla_min_cm`, `cupo_dia`, `periodo`, `hasta_hora`,
`solo_si_preemergencia`, etc. Lo interpreta el motor según la actividad.

## Vigilancia de fuentes (Fase 7b)

`vigilancia_fuentes.py` detecta (sin IA, solo hashes) si un documento oficial
vigilado ha cambiado. Estado en `curacion/fuentes_vigiladas.json`.

- **Detección**: la GitHub Action `vigilancia-fuentes.yml` corre semanal y, si una
  fuente cambia, abre un issue. Es gratis y no gasta plan.
- **Extracción a borrador** (IA): a demanda, cuando el issue avisa. Claude re-lee
  el documento, extrae las reglas al JSON y las inserta con `curacion.py` (borrador).
  Tras curar: `python3 vigilancia_fuentes.py --update` para fijar el nuevo hash.
- **Publicar**: siempre manual (regla de oro).

Añadir una fuente: nueva entrada en `fuentes_vigiladas.json` y `--init` para su hash.
