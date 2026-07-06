"""
Pipeline diario: nivel de preemergencia de incendios de la Comunitat Valenciana.

Fuente oficial (HTML server-rendered, sin JS):
    https://prevencionincendiosgva.es/Meteorologia/NivelPreemergenciaList
Por defecto esa página devuelve una tabla con la última semana. Cada día trae dos
filas: "Alerta" (nivel de preemergencia de incendios 1/2/3 por zona, lo que nos
interesa) y "Tormenta" (riesgo de tormenta, se ignora). Columnas de zona, en orden:
    Z. 1N | Z. 1S | Z. 2 | Z. 3 | Z. 4 | Z. 5 | Z. 6   (ZonaID 1..7)

Corre cada mañana en GitHub Actions. Flujo:
    1. Descarga la página oficial.
    2. Parsea la fila "Alerta" de HOY -> 7 niveles por zona.
    3. Valida: ¿hay dato de hoy? ¿7 zonas? ¿niveles en 1-3? Si no, aborta SIN
       escribir. El motor trata la ausencia de dato como rojo, así que no escribir
       es la opción segura.
    4. UPSERT a condiciones_diarias vía REST con la service_role.

Diseño defensivo: cualquier anomalía de parseo -> NO escribe y sale con error.
Es preferible "sin dato -> rojo" a escribir un dato dudoso que pinte un verde falso.

Uso:
    python3 ingesta_preemergencia.py --demo      # muestra local, sin red ni escritura
    python3 ingesta_preemergencia.py --dry-run   # descarga y parsea real, NO escribe
    python3 ingesta_preemergencia.py             # producción: descarga, valida y escribe
"""

import os
import re
import sys
import html
import json
import urllib.request
import urllib.parse
from datetime import datetime, date, timezone

FUENTE_URL = "https://prevencionincendiosgva.es/Meteorologia/NivelPreemergenciaList"
ZONAS_ESPERADAS = 7
NIVELES_VALIDOS = {"1", "2", "3"}

# Orden de columnas de zona en la tabla oficial -> codigo de TERRITORIOS.
# La columna i (0..6) es la ZonaID i+1; los codigos del seed son CV-PREF-Z{ZonaID}.
COL_A_CODIGO = [f"CV-PREF-Z{i+1}" for i in range(ZONAS_ESPERADAS)]


class ValidacionError(Exception):
    pass


# ---------------------------------------------------------------------------
# 1. Descarga
# ---------------------------------------------------------------------------

def descargar_html():
    req = urllib.request.Request(FUENTE_URL, headers={
        "User-Agent": "Vedra/1.0 (ingesta preemergencia; contacto@vedra.app)"})
    with urllib.request.urlopen(req, timeout=40) as resp:
        return resp.read().decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# 2. Parseo — fila "Alerta" de hoy
# ---------------------------------------------------------------------------

def _celdas(tr):
    return [html.unescape(re.sub("<.*?>", "", c)).strip()
            for c in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S | re.I)]


def parsear(html_txt, hoy=None):
    """
    Devuelve (fecha_boletin: date, niveles: [str]*7) para la fila 'Alerta' de hoy.
    Si no encuentra la fila de hoy, devuelve (None, []).
    """
    hoy = hoy or date.today()
    hoy_str = hoy.strftime("%d/%m/%Y")

    m = re.search(r"<table[^>]*>(.*?)</table>", html_txt, re.S | re.I)
    if not m:
        return None, []
    filas = re.findall(r"<tr[^>]*>(.*?)</tr>", m.group(1), re.S | re.I)

    for tr in filas:
        tds = _celdas(tr)
        # La fila 'Alerta' de un día: [fecha, 'Alerta', n1..n7, comentarios]
        if len(tds) >= 9 and tds[0] == hoy_str and tds[1].lower().startswith("alerta"):
            niveles = tds[2:2 + ZONAS_ESPERADAS]
            return hoy, niveles
    return None, []


# ---------------------------------------------------------------------------
# 3. Validación defensiva
# ---------------------------------------------------------------------------

def validar(fecha_boletin, niveles, hoy=None):
    hoy = hoy or date.today()
    if fecha_boletin is None:
        raise ValidacionError("No se encontró la fila 'Alerta' de hoy en la tabla.")
    if fecha_boletin != hoy:
        raise ValidacionError(f"Boletín con fecha {fecha_boletin}, hoy es {hoy}. No se escribe.")
    if len(niveles) != ZONAS_ESPERADAS:
        raise ValidacionError(f"Se esperaban {ZONAS_ESPERADAS} niveles, se parsearon {len(niveles)}. Posible cambio de maquetación.")
    for i, n in enumerate(niveles):
        if n not in NIVELES_VALIDOS:
            raise ValidacionError(f"Nivel inválido '{n}' en columna {i} ({COL_A_CODIGO[i]}).")
    return True


# ---------------------------------------------------------------------------
# 4. Escritura (REST / PostgREST con service_role)
# ---------------------------------------------------------------------------

def _rest(metodo, ruta, key, body=None, extra_headers=None):
    url = os.environ["SUPABASE_URL"].rstrip("/") + ruta
    headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    if extra_headers:
        headers.update(extra_headers)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=metodo)
    with urllib.request.urlopen(req, timeout=30) as r:
        txt = r.read().decode()
        return json.loads(txt) if txt.strip() else []


def resolver_territorios(codigos, key):
    """codigo -> uuid, leyendo TERRITORIOS. Aborta si falta alguna zona."""
    lista = ",".join(codigos)
    filas = _rest("GET", f"/rest/v1/territorios?select=id,codigo&codigo=in.({lista})", key)
    mapa = {f["codigo"]: f["id"] for f in filas}
    faltan = [c for c in codigos if c not in mapa]
    if faltan:
        raise ValidacionError(f"Territorios sin dar de alta para las zonas: {faltan}. No se escribe.")
    return mapa


def construir_registros(fecha_boletin, niveles, territorio_map, ahora=None):
    ahora = (ahora or datetime.now(timezone.utc)).isoformat()
    registros = []
    for i, nivel in enumerate(niveles):
        codigo = COL_A_CODIGO[i]
        registros.append({
            "territorio_id": territorio_map[codigo],
            "fecha": fecha_boletin.isoformat(),
            "tipo": "preemergencia_incendios",
            "nivel": nivel,
            "obtenido_en": ahora,
            "fuente_url": FUENTE_URL,
        })
    return registros


def escribir_supabase(registros):
    """UPSERT sobre la PK (territorio_id, fecha, tipo). Solo con service_role."""
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not (os.environ.get("SUPABASE_URL") and key):
        print("[!] Sin SUPABASE_URL/SERVICE_KEY; volcando a stdout en su lugar.\n")
        print(json.dumps(registros, indent=2, ensure_ascii=False))
        return
    _rest("POST", "/rest/v1/condiciones_diarias?on_conflict=territorio_id,fecha,tipo",
          key, body=registros,
          extra_headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
    print(f"[✓] UPSERT de {len(registros)} registros en condiciones_diarias.")


# ---------------------------------------------------------------------------
# Muestra para --demo (tabla representativa; no es la web real)
# ---------------------------------------------------------------------------

HTML_DEMO = """
<table>
<tr><th>Fecha</th><th>Z. 1N</th><th>Z. 1S</th><th>Z. 2</th><th>Z. 3</th><th>Z. 4</th><th>Z. 5</th><th>Z. 6</th><th>Comentarios</th></tr>
<tr><td>{hoy}</td><td>Alerta</td><td>1</td><td>2</td><td>1</td><td>2</td><td>3</td><td>2</td><td>1</td><td>Queda prohibida la quema... nivel 1 hasta las 11 h.</td></tr>
<tr><td>Tormenta</td><td>1</td><td>1</td><td>1</td><td>2</td><td>1</td><td>2</td><td>1</td></tr>
</table>
""".format(hoy=date.today().strftime("%d/%m/%Y"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    demo = "--demo" in sys.argv
    dry = "--dry-run" in sys.argv
    modo = "DEMO" if demo else ("DRY-RUN" if dry else "PRODUCCIÓN")
    print(f"[i] Ingesta preemergencia — {modo} — {datetime.now(timezone.utc).isoformat()}\n")

    try:
        html_txt = HTML_DEMO if demo else descargar_html()
        fecha_boletin, niveles = parsear(html_txt)
        print(f"[i] Fila 'Alerta' de hoy: fecha={fecha_boletin} niveles={niveles}")
        validar(fecha_boletin, niveles)
        print("[✓] Validación OK.\n")

        if demo or dry:
            key = os.environ.get("SUPABASE_SERVICE_KEY", "")
            if key:
                territorio_map = resolver_territorios(COL_A_CODIGO, key)
            else:
                territorio_map = {c: f"<uuid-{c}>" for c in COL_A_CODIGO}
            registros = construir_registros(fecha_boletin, niveles, territorio_map)
            print("[i] Registros que se escribirían (no se escribe en demo/dry-run):\n")
            print(json.dumps(registros, indent=2, ensure_ascii=False))
            return

        key = os.environ["SUPABASE_SERVICE_KEY"]
        territorio_map = resolver_territorios(COL_A_CODIGO, key)
        registros = construir_registros(fecha_boletin, niveles, territorio_map)
        escribir_supabase(registros)
        print(f"\n[✓] {len(registros)} zonas actualizadas para {fecha_boletin}.")
    except ValidacionError as e:
        print(f"[✗] Validación falló: {e}")
        print("    No se escribe nada. La app degradará a rojo por falta de dato fresco.")
        sys.exit(1)
    except Exception as e:
        print(f"[✗] Error inesperado: {e}")
        sys.exit(2)


if __name__ == "__main__":
    main()
