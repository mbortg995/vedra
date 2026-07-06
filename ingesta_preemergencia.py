"""
Pipeline diario: nivel de preemergencia de incendios de la Comunitat Valenciana.

Fuente oficial: https://prevencionincendiosgva.es/Meteorology/NivelPreemergencia
La GVA (vía AEMET) publica un nivel diario (1/2/3) para cada una de las 7 zonas
Previfoc de la Comunitat.

Corre cada mañana en GitHub Actions. Flujo:
    1. Descarga la página oficial.
    2. Parsea el nivel por zona.
    3. Valida: ¿hay dato de hoy? ¿está fresco? Si no, aborta SIN escribir
       (el motor ya trata la ausencia de dato como rojo, así que no escribir
        es la opción segura).
    4. Genera los UPSERT para condiciones_diarias en Supabase.

Diseño defensivo: si la estructura de la web cambia y el parseo devuelve algo
inesperado (nivel fuera de 1-3, menos de N zonas), NO escribe y avisa. Es
preferible que la app diga "sin dato -> rojo" a que escriba un dato erróneo
que pinte un verde falso sobre un día de riesgo real.

Uso:
    python3 ingesta_preemergencia.py --demo      # usa muestra local, no red
    python3 ingesta_preemergencia.py             # producción (requiere red + env)
"""

import sys
import re
import json
from datetime import datetime, date, timezone

FUENTE_URL = "https://prevencionincendiosgva.es/Meteorology/NivelPreemergencia"
ZONAS_ESPERADAS = 7           # la Comunitat se divide en 7 zonas Previfoc
NIVELES_VALIDOS = {"1", "2", "3"}

# Mapa de nombre de zona oficial -> id de territorio en tu tabla TERRITORIOS.
# Lo rellenas una vez al dar de alta las zonas. Ejemplo parcial:
MAPA_ZONA_TERRITORIO = {
    "Zona 1": "cv-pref-z1",
    "Zona 2": "cv-pref-z2",
    "Zona 3": "cv-pref-z3",
    "Zona 4": "cv-pref-z4",
    "Zona 5": "cv-pref-z5",
    "Zona 6": "cv-pref-z6",
    "Zona 7": "cv-pref-z7",
}


# ---------------------------------------------------------------------------
# 1. Descarga
# ---------------------------------------------------------------------------

def descargar_html():
    import urllib.request
    req = urllib.request.Request(FUENTE_URL, headers={"User-Agent": "OutdoorApp/1.0 (contacto@ejemplo.com)"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# 2. Parseo
# ---------------------------------------------------------------------------

def parsear(html):
    """
    Devuelve (fecha_boletin, [{'zona':..., 'nivel':...}, ...]).

    NOTA: el selector exacto depende del HTML real de la página. Este parser
    busca un patrón genérico "Zona N ... nivel D" que deberás afinar la primera
    vez inspeccionando el HTML real. La estrategia de validación posterior es lo
    que te protege de que un cambio de maquetación cuele datos basura.
    """
    # Fecha del boletín (dd/mm/aaaa en la página). Si no se encuentra, None.
    m_fecha = re.search(r"(\d{2})/(\d{2})/(\d{4})", html)
    fecha_boletin = None
    if m_fecha:
        d, mth, y = m_fecha.groups()
        fecha_boletin = date(int(y), int(mth), int(d))

    # Pares Zona -> nivel. Patrón deliberadamente simple; afinar con el HTML real.
    filas = []
    for m in re.finditer(r"(Zona\s*\d)\D{0,80}?nivel[^\d]{0,20}(\d)", html, re.IGNORECASE | re.DOTALL):
        zona = re.sub(r"\s+", " ", m.group(1)).strip().title()
        nivel = m.group(2)
        filas.append({"zona": zona, "nivel": nivel})

    # Dedup por zona (por si el patrón captura repetidos), conservando el primero.
    vistas, unicas = set(), []
    for f in filas:
        if f["zona"] not in vistas:
            vistas.add(f["zona"])
            unicas.append(f)
    return fecha_boletin, unicas


# ---------------------------------------------------------------------------
# 3. Validación defensiva
# ---------------------------------------------------------------------------

class ValidacionError(Exception):
    pass


def validar(fecha_boletin, filas, hoy=None):
    hoy = hoy or date.today()

    if fecha_boletin is None:
        raise ValidacionError("No se encontró la fecha del boletín en la página.")

    # El boletín es diario. Aceptamos hoy o ayer (por si se corre de madrugada
    # antes de la actualización). Más viejo -> abortar.
    dias = (hoy - fecha_boletin).days
    if dias < 0 or dias > 1:
        raise ValidacionError(f"Boletín con fecha {fecha_boletin}, hoy es {hoy}. Fuera de rango; no se escribe.")

    if len(filas) < ZONAS_ESPERADAS:
        raise ValidacionError(f"Se esperaban {ZONAS_ESPERADAS} zonas, se parsearon {len(filas)}. Posible cambio de maquetación.")

    for f in filas:
        if f["nivel"] not in NIVELES_VALIDOS:
            raise ValidacionError(f"Nivel inválido '{f['nivel']}' en {f['zona']}.")
        if f["zona"] not in MAPA_ZONA_TERRITORIO:
            raise ValidacionError(f"Zona desconocida '{f['zona']}' sin territorio mapeado.")

    return True


# ---------------------------------------------------------------------------
# 4. Generación de UPSERTs (Supabase)
# ---------------------------------------------------------------------------

def construir_registros(fecha_boletin, filas, ahora=None):
    ahora = ahora or datetime.now(timezone.utc)
    registros = []
    for f in filas:
        registros.append({
            "territorio_id": MAPA_ZONA_TERRITORIO[f["zona"]],
            "fecha": fecha_boletin.isoformat(),
            "tipo": "preemergencia_incendios",
            "nivel": f["nivel"],
            "obtenido_en": ahora.isoformat(),
            "fuente_url": FUENTE_URL,
        })
    return registros


def escribir_supabase(registros):
    """
    En producción: upsert vía supabase-py o REST. Clave de conflicto:
    (territorio_id, fecha, tipo) -> reescribe si ya existía.
    Aquí solo lo imprime.
    """
    import os
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not (url and key):
        print("[!] Sin credenciales Supabase en entorno; volcando a stdout en su lugar.\n")
        print(json.dumps(registros, indent=2, ensure_ascii=False))
        return
    # from supabase import create_client
    # sb = create_client(url, key)
    # sb.table("condiciones_diarias").upsert(registros, on_conflict="territorio_id,fecha,tipo").execute()
    print(json.dumps(registros, indent=2, ensure_ascii=False))


# ---------------------------------------------------------------------------
# Muestra para --demo (HTML representativo, no es la web real)
# ---------------------------------------------------------------------------

HTML_DEMO = """
<html><body>
<h1>Nivel de Preemergencia — Boletín del {fecha}</h1>
<table>
  <tr><td>Zona 1</td><td>Litoral Norte</td><td>nivel 1</td></tr>
  <tr><td>Zona 2</td><td>Interior Norte</td><td>nivel 2</td></tr>
  <tr><td>Zona 3</td><td>Litoral Centro</td><td>nivel 1</td></tr>
  <tr><td>Zona 4</td><td>Interior Centro</td><td>nivel 2</td></tr>
  <tr><td>Zona 5</td><td>Litoral Sur</td><td>nivel 3</td></tr>
  <tr><td>Zona 6</td><td>Interior Sur</td><td>nivel 2</td></tr>
  <tr><td>Zona 7</td><td>Montaña</td><td>nivel 1</td></tr>
</table>
</body></html>
""".format(fecha=date.today().strftime("%d/%m/%Y"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    demo = "--demo" in sys.argv
    print(f"[i] Ingesta preemergencia — {'DEMO' if demo else 'PRODUCCIÓN'} — {datetime.now(timezone.utc).isoformat()}\n")

    try:
        html = HTML_DEMO if demo else descargar_html()
        fecha_boletin, filas = parsear(html)
        print(f"[i] Boletín {fecha_boletin} — {len(filas)} zonas parseadas.")
        validar(fecha_boletin, filas)
        print("[✓] Validación OK.\n")
        registros = construir_registros(fecha_boletin, filas)
        escribir_supabase(registros)
        print(f"\n[✓] {len(registros)} registros listos para condiciones_diarias.")
    except ValidacionError as e:
        # Fallo controlado: NO se escribe nada. El motor tratará la ausencia de
        # dato fresco como rojo, que es el comportamiento seguro.
        print(f"[✗] Validación falló: {e}")
        print("    No se escribe nada. La app degradará a rojo por falta de dato fresco.")
        sys.exit(1)
    except Exception as e:
        print(f"[✗] Error inesperado: {e}")
        sys.exit(2)


if __name__ == "__main__":
    main()
