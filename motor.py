"""
Motor de evaluación de referencia — "¿Puedo hacer X aquí hoy?"

Esto es la lógica pura. En producción vive en una Edge Function de Supabase y
las consultas de territorios/reglas son SQL contra PostGIS. Aquí se simula la
capa de datos con diccionarios en memoria para que se ejecute sin dependencias
y puedas ver el semáforo funcionando.

    python3 motor.py
"""

from datetime import datetime, date, timezone, timedelta
from dataclasses import dataclass, field


# ----------------------------------------------------------------------------
# Capa de datos simulada (en producción: PostGIS + tablas del ERD)
# ----------------------------------------------------------------------------

# Árbol de territorios que contiene un punto dado. En producción esto es UNA
# query espacial: ST_Contains(geom, punto) subiendo por padre_id.
def territorios_que_contienen(lat, lon):
    # Simulación: un punto en el interior de Castelló.
    return [
        {"id": "cv",   "nivel": "ccaa",      "nombre": "Comunitat Valenciana"},
        {"id": "z4",   "nivel": "zona_pref", "nombre": "Zona 4 - Interior Norte de Castelló"},
        {"id": "arec", "nivel": "area",      "nombre": "Àrea recreativa Penyagolosa"},
    ]

# Reglas vigentes hoy para (actividad, territorios). En producción: SELECT ...
# WHERE actividad_id = ? AND territorio_id IN (...) AND vigencia @> fecha
#   AND estado_revision = 'publicada'
REGLAS = {
    "fuego_recreativo": [
        {"territorio": "cv", "capa": "estacional", "efecto": "limita",
         "parametros": {"periodo": ["06-01", "10-15"], "solo_si_preemergencia": "1", "hasta_hora": "11:00"},
         "detalle": "Fuego solo en paellero habilitado, preemergencia 1 y hasta las 11:00 h.",
         "fuente": {"organismo": "GVA - Prevención Incendios", "fecha": "2026-06-01", "url": "https://prevencionincendiosgva.es/"}},
        {"territorio": "arec", "capa": "permanente", "efecto": "requiere",
         "requisito": "usar_paellero_habilitado",
         "detalle": "Solo en los paelleros del área recreativa.",
         "fuente": {"organismo": "GVA", "fecha": "2026-01-01", "url": "https://prevencionincendiosgva.es/"}},
    ],
    "setas": [
        {"territorio": "cv", "capa": "permanente", "efecto": "limita",
         "parametros": {"kg_max_dia": 10},
         "detalle": "Máximo orientativo por persona y día.",
         "fuente": {"organismo": "GVA - Medi Natural", "fecha": "2026-01-01", "url": "https://..."}},
    ],
}

# Condición diaria por territorio. En producción: SELECT ... FROM condiciones_diarias
# WHERE territorio_id = ? AND fecha = ? (y se comprueba obtenido_en).
CONDICIONES_DIARIAS = {
    ("cv", date(2026, 7, 6)): {
        "tipo": "preemergencia_incendios", "nivel": "1",
        "obtenido_en": datetime(2026, 7, 6, 7, 12, tzinfo=timezone.utc),
        "fuente": {"organismo": "GVA / AEMET", "url": "https://prevencionincendiosgva.es/Meteorology/NivelPreemergencia"},
    },
}

# Licencias del usuario. En producción: tabla licencias_usuario.
LICENCIAS_USUARIO = {
    "user-con-todo": {"usar_paellero_habilitado"},  # (permiso simbólico)
    "user-sin-nada": set(),
}

# Actividades cuya seguridad depende del dato diario. Si el dato falta o es viejo,
# el motor degrada a rojo.
DEPENDE_DE_DIA = {"fuego_recreativo"}
# Con preemergencia 3, estas actividades también se ven afectadas.
AFECTADAS_POR_PREEMERGENCIA_3 = {"fuego_recreativo", "acampada", "setas"}

FRESCURA_MAX = timedelta(hours=30)  # el boletín es diario; 30 h da margen a un retraso


# ----------------------------------------------------------------------------
# Motor
# ----------------------------------------------------------------------------

@dataclass
class Resultado:
    semaforo: str = "verde"
    titulo: str = ""
    territorios: list = field(default_factory=list)
    requisitos: list = field(default_factory=list)
    bloqueos: list = field(default_factory=list)
    condiciones_dia: list = field(default_factory=list)
    avisos: list = field(default_factory=list)
    generado_en: str = ""
    disclaimer: str = "Información orientativa. Consulta siempre la fuente oficial antes de actuar."


def evaluar(actividad, lat, lon, fecha=None, usuario_id=None, ahora=None):
    fecha = fecha or date.today()
    ahora = ahora or datetime.now(timezone.utc)
    r = Resultado(generado_en=ahora.isoformat())

    cadena = territorios_que_contienen(lat, lon)
    r.territorios = cadena
    ids = {t["id"] for t in cadena}

    # --- Condición diaria (se busca en el territorio de mayor nivel que la tenga) ---
    condicion = None
    for t in cadena:
        c = CONDICIONES_DIARIAS.get((t["id"], fecha))
        if c:
            condicion = c
            break

    fresco = False
    if condicion:
        fresco = (ahora - condicion["obtenido_en"]) <= FRESCURA_MAX
        r.condiciones_dia.append({
            "tipo": condicion["tipo"], "nivel": condicion["nivel"],
            "obtenido_en": condicion["obtenido_en"].isoformat(),
            "fresco": fresco, "fuente": condicion["fuente"],
        })

    # --- REGLA 1: dato diario ausente/caduco en actividad que lo requiere -> rojo ---
    if actividad in DEPENDE_DE_DIA and (condicion is None or not fresco):
        r.semaforo = "rojo"
        r.titulo = "No podemos confirmarlo — trátalo como prohibido"
        r.avisos.append("No hay dato oficial de preemergencia fresco para hoy. Por seguridad, no enciendas fuego.")
        return r

    # --- REGLA 2: bloqueo por preemergencia 3 sobre actividades afectadas -> rojo ---
    if condicion and condicion["nivel"] == "3" and actividad in AFECTADAS_POR_PREEMERGENCIA_3:
        r.semaforo = "rojo"
        r.titulo = "Prohibido hoy por nivel de preemergencia 3"
        r.bloqueos.append({
            "motivo": "preemergencia_incendios_nivel_3",
            "detalle": "Medidas extraordinarias de obligado cumplimiento en terreno forestal.",
            "fuente": condicion["fuente"],
        })
        return r

    # --- Recolectar reglas aplicables y construir requisitos ---
    tiene = LICENCIAS_USUARIO.get(usuario_id, set())
    for regla in REGLAS.get(actividad, []):
        if regla["territorio"] not in ids:
            continue

        if regla["efecto"] == "prohibe":
            r.bloqueos.append({"detalle": regla["detalle"], "fuente": regla["fuente"]})

        elif regla["efecto"] == "requiere":
            req = regla["requisito"]
            r.requisitos.append({
                "tipo": req,
                "cumplido": (usuario_id is not None and req in tiene),
                "detalle": regla["detalle"], "fuente": regla["fuente"],
            })

        elif regla["efecto"] == "limita":
            p = regla["parametros"]
            if "kg_max_dia" in p:
                r.avisos.append(f"Máximo {p['kg_max_dia']} kg por persona y día.")
            if "solo_si_preemergencia" in p and condicion:
                if condicion["nivel"] != p["solo_si_preemergencia"]:
                    r.bloqueos.append({
                        "detalle": f"Fuego permitido solo con preemergencia {p['solo_si_preemergencia']} (hoy: {condicion['nivel']}).",
                        "fuente": regla["fuente"],
                    })
                else:
                    r.avisos.append(f"{regla['detalle']}")

    # --- Semáforo final ---
    if r.bloqueos:
        r.semaforo = "rojo"
        r.titulo = "Hoy no puedes aquí"
    elif any(not req["cumplido"] for req in r.requisitos):
        r.semaforo = "amarillo"
        r.titulo = "Puedes, pero te falta algo o inicia sesión"
    else:
        r.semaforo = "verde"
        r.titulo = "Adelante — cumples todo"
    return r


# ----------------------------------------------------------------------------
# Demostración
# ----------------------------------------------------------------------------

def pinta(titulo, res):
    icono = {"verde": "🟢", "amarillo": "🟡", "rojo": "🔴"}[res.semaforo]
    print(f"\n{'='*66}\n{titulo}\n{'='*66}")
    print(f"{icono}  {res.semaforo.upper()} — {res.titulo}")
    if res.condiciones_dia:
        c = res.condiciones_dia[0]
        estado = "fresco" if c["fresco"] else "CADUCO"
        print(f"   Preemergencia: nivel {c['nivel']} ({estado})")
    for req in res.requisitos:
        mark = "✓" if req["cumplido"] else "✗"
        print(f"   [{mark}] {req['detalle']}")
    for b in res.bloqueos:
        print(f"   ⛔ {b['detalle']}")
    for a in res.avisos:
        print(f"   ℹ  {a}")


if __name__ == "__main__":
    hoy = date(2026, 7, 6)
    manana_frio = datetime(2026, 7, 6, 8, 0, tzinfo=timezone.utc)

    pinta("1. Fuego, usuario con permiso, preemergencia 1, dato fresco",
          evaluar("fuego_recreativo", 39.98, -0.05, hoy, "user-con-todo", manana_frio))

    pinta("2. Fuego, usuario SIN permiso registrado (mismo día)",
          evaluar("fuego_recreativo", 39.98, -0.05, hoy, "user-sin-nada", manana_frio))

    # Simula dato viejo: evaluamos 40 h después de obtenido_en
    tarde = datetime(2026, 7, 7, 23, 0, tzinfo=timezone.utc)
    pinta("3. Fuego, pero el dato de preemergencia está caduco -> rojo por seguridad",
          evaluar("fuego_recreativo", 39.98, -0.05, hoy, "user-con-todo", tarde))

    # Simula preemergencia 3 inyectándola
    CONDICIONES_DIARIAS[("cv", hoy)]["nivel"] = "3"
    pinta("4. Setas en día de preemergencia 3 -> rojo (afecta a más que el fuego)",
          evaluar("setas", 39.98, -0.05, hoy, "user-con-todo", manana_frio))
    CONDICIONES_DIARIAS[("cv", hoy)]["nivel"] = "1"  # restaura

    pinta("5. Setas, día normal -> verde con aviso de kg máximos",
          evaluar("setas", 39.98, -0.05, hoy, "user-con-todo", manana_frio))
