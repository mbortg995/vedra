"""
Motor de evaluación de referencia — "¿Puedo hacer X aquí hoy?"

Esto es la lógica pura del semáforo. Los datos (territorios, reglas, condiciones,
licencias) llegan por un proveedor (ver datos.py), así que la MISMA lógica sirve
tanto para los diccionarios en memoria (tests) como para Supabase por REST.

    python3 motor.py                 # 5 casos deterministas (DatosMemoria)
    python3 validar_supabase.py      # evaluación en vivo contra Supabase
"""

import re
from datetime import datetime, date, timezone, timedelta
from dataclasses import dataclass, field


# ----------------------------------------------------------------------------
# Configuración de la lógica (parte del contrato, no "datos")
# ----------------------------------------------------------------------------

# Actividades cuya seguridad depende del dato diario. Si falta o es viejo -> rojo.
DEPENDE_DE_DIA = {"fuego_recreativo", "quema"}
# Con preemergencia 3, estas actividades también se ven afectadas.
AFECTADAS_POR_PREEMERGENCIA_3 = {"fuego_recreativo", "acampada", "setas", "quema"}
# El boletín es diario; 30 h da margen a un retraso antes de considerarlo caduco.
FRESCURA_MAX = timedelta(hours=30)


def _en_vigencia(vigencia, fecha):
    """True si `fecha` cae dentro del daterange (o si no hay vigencia). Postgres
    serializa el daterange normalizado a '[bajo,alto)' (bajo incl., alto excl.);
    extremos vacíos = sin límite. No parseable -> True (aplicar; lado seguro)."""
    if not vigencia:
        return True
    m = re.match(r"^[\[(]([^,]*),([^,]*)[\])]$", vigencia.strip())
    if not m:
        return True
    bajo, alto = m.group(1), m.group(2)
    if bajo and fecha < date.fromisoformat(bajo):
        return False
    if alto and fecha >= date.fromisoformat(alto):
        return False
    return True


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


def evaluar(datos, actividad, lat, lon, fecha=None, usuario_id=None, ahora=None):
    """`datos` es un proveedor con la interfaz de datos.py (memoria o Supabase)."""
    fecha = fecha or date.today()
    ahora = ahora or datetime.now(timezone.utc)
    r = Resultado(generado_en=ahora.isoformat())

    cadena = datos.territorios_que_contienen(lat, lon)
    r.territorios = cadena
    ids = {t["id"] for t in cadena}

    # --- Condición diaria (en el territorio de mayor nivel que la tenga) ---
    condicion = None
    for t in cadena:
        c = datos.condicion_diaria(t["id"], fecha)
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
    tiene = datos.licencias(usuario_id)
    for regla in datos.reglas_actividad(actividad):
        if regla["territorio"] not in ids:
            continue
        # Estacionales: fuera de su vigencia (veda, periodo hábil) no aplican (#30).
        if not _en_vigencia(regla.get("vigencia"), fecha):
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
# Demostración: 5 casos deterministas contra el proveedor en memoria
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
    from datos import DatosMemoria
    dm = DatosMemoria()
    hoy = date(2026, 7, 6)
    manana_frio = datetime(2026, 7, 6, 8, 0, tzinfo=timezone.utc)

    pinta("1. Fuego, usuario con permiso, preemergencia 1, dato fresco",
          evaluar(dm, "fuego_recreativo", 39.98, -0.05, hoy, "user-con-todo", manana_frio))

    pinta("2. Fuego, usuario SIN permiso registrado (mismo día)",
          evaluar(dm, "fuego_recreativo", 39.98, -0.05, hoy, "user-sin-nada", manana_frio))

    # Simula dato viejo: evaluamos 40 h después de obtenido_en
    tarde = datetime(2026, 7, 7, 23, 0, tzinfo=timezone.utc)
    pinta("3. Fuego, pero el dato de preemergencia está caduco -> rojo por seguridad",
          evaluar(dm, "fuego_recreativo", 39.98, -0.05, hoy, "user-con-todo", tarde))

    # Simula preemergencia 3 inyectándola
    dm.CONDICIONES_DIARIAS[("cv", hoy)]["nivel"] = "3"
    pinta("4. Setas en día de preemergencia 3 -> rojo (afecta a más que el fuego)",
          evaluar(dm, "setas", 39.98, -0.05, hoy, "user-con-todo", manana_frio))
    dm.CONDICIONES_DIARIAS[("cv", hoy)]["nivel"] = "1"  # restaura

    pinta("5. Setas, día normal -> verde con aviso de kg máximos",
          evaluar(dm, "setas", 39.98, -0.05, hoy, "user-con-todo", manana_frio))

    # --- Comprobaciones de vigencia (#30) ---
    assert _en_vigencia(None, hoy) is True
    assert _en_vigencia("[2026-06-01,2026-10-16)", date(2026, 7, 9)) is True
    assert _en_vigencia("[2020-06-01,2020-10-16)", date(2026, 7, 9)) is False
    assert _en_vigencia("[2026-07-09,2026-08-01)", date(2026, 7, 9)) is True   # bajo inclusivo
    assert _en_vigencia("[2026-01-01,2026-07-09)", date(2026, 7, 9)) is False  # alto exclusivo
    print("\n[✓] #30 vigencia: comprobaciones OK.")
