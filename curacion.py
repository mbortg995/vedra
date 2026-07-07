"""
Curación asistida de normativa: reglas en borrador -> revisada -> publicada.

El "cerebro" que interpreta el documento oficial es Claude Code (esta sesión o,
en la Fase 7b, una routine programada), NO una API de pago. Este script es la
parte DETERMINISTA: inserta los borradores que Claude extrae (un JSON) en la BD,
los lista y los promueve entre estados. Guardarraíl de la regla de oro:
  - insertar SIEMPRE deja las reglas en 'borrador'.
  - publicar exige que la regla esté ya 'revisada' (no se salta la revisión).
Solo biblioteca estándar; usa la service_role del .env.

Uso:
    python3 curacion.py insertar reglas.json        # inserta como 'borrador'
    python3 curacion.py listar [--estado borrador]  # lista reglas
    python3 curacion.py revisar  <id>               # borrador -> revisada
    python3 curacion.py publicar <id>               # revisada -> publicada
    python3 curacion.py rechazar <id>               # borra un borrador/revisada

Esquema del JSON (lista de reglas) -> ver curacion.md.
"""

import os
import sys
import json
import urllib.request
import urllib.parse

# Carga simple del .env local.
_envp = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
if os.path.exists(_envp):
    for _l in open(_envp):
        _l = _l.strip()
        if _l and not _l.startswith("#") and "=" in _l:
            _k, _v = _l.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")


def _req(metodo, ruta, body=None, prefer=None):
    if not (URL and KEY):
        sys.exit("Faltan SUPABASE_URL / SUPABASE_SERVICE_KEY en el entorno (.env).")
    headers = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + ruta, data=data, headers=headers, method=metodo)
    with urllib.request.urlopen(req, timeout=30) as r:
        txt = r.read().decode()
        return json.loads(txt) if txt.strip() else []


def _uno(tabla, filtro, select="id"):
    filas = _req("GET", f"/rest/v1/{tabla}?{filtro}&select={select}")
    return filas[0] if filas else None


def _fuente_id(fuente):
    """Reutiliza la fuente por url si existe; si no, la crea."""
    url = fuente.get("url")
    if url:
        ex = _uno("fuentes", f"url=eq.{urllib.parse.quote(url)}")
        if ex:
            return ex["id"]
    creada = _req("POST", "/rest/v1/fuentes", body=fuente, prefer="return=representation")
    return creada[0]["id"]


def _daterange(vig):
    if not vig:
        return None
    return f"[{vig[0]},{vig[1]})"


def insertar(archivo):
    reglas = json.load(open(archivo, encoding="utf-8"))
    if isinstance(reglas, dict):
        reglas = [reglas]
    print(f"[i] Insertando {len(reglas)} regla(s) como 'borrador'...")
    for i, r in enumerate(reglas, 1):
        terr = _uno("territorios", f"codigo=eq.{r['territorio_codigo']}")
        act = _uno("actividades", f"slug=eq.{r['actividad_slug']}")
        if not terr:
            sys.exit(f"[✗] Territorio '{r['territorio_codigo']}' no existe.")
        if not act:
            sys.exit(f"[✗] Actividad '{r['actividad_slug']}' no existe.")
        fila = {
            "territorio_id": terr["id"],
            "actividad_id": act["id"],
            "fuente_id": _fuente_id(r["fuente"]),
            "capa": r["capa"],
            "efecto": r["efecto"],
            "parametros": r.get("parametros", {}),
            "vigencia": _daterange(r.get("vigencia")),
            "detalle": r.get("detalle"),
            "cita": r.get("cita"),
            "estado_revision": "borrador",   # SIEMPRE borrador
        }
        creada = _req("POST", "/rest/v1/reglas", body=fila, prefer="return=representation")
        rid = creada[0]["id"]
        for slug in r.get("requisitos", []):
            tr = _uno("tipos_requisito", f"slug=eq.{slug}")
            if not tr:
                sys.exit(f"[✗] Tipo de requisito '{slug}' no existe.")
            _req("POST", "/rest/v1/regla_requisitos",
                 body={"regla_id": rid, "tipo_requisito_id": tr["id"]}, prefer="return=minimal")
        print(f"  [{i}] borrador creado: {rid}  ({r['actividad_slug']} · {r['efecto']}) {r.get('detalle','')[:50]}")
    print("[✓] Hecho. Revisa con: python3 curacion.py listar --estado borrador")


def listar(estado=None):
    filtro = f"estado_revision=eq.{estado}&" if estado else ""
    filas = _req("GET", f"/rest/v1/reglas?{filtro}select=id,estado_revision,capa,efecto,detalle,"
                        "actividades(slug),territorios(codigo)&order=estado_revision")
    if not filas:
        print("(sin reglas)")
        return
    for f in filas:
        print(f"  {f['id']}  [{f['estado_revision']:<9}] {f['territorios']['codigo']:<10} "
              f"{f['actividades']['slug']:<16} {f['efecto']:<10} {f.get('detalle','')[:60]}")


def _cambiar_estado(rid, desde, hasta):
    filas = _req("PATCH", f"/rest/v1/reglas?id=eq.{rid}&estado_revision=eq.{desde}",
                 body={"estado_revision": hasta}, prefer="return=representation")
    if not filas:
        sys.exit(f"[✗] No se cambió nada. ¿La regla {rid} está en estado '{desde}'?")
    print(f"[✓] Regla {rid}: {desde} -> {hasta}")


def revisar(rid):
    _cambiar_estado(rid, "borrador", "revisada")


def publicar(rid):
    # Exige 'revisada': no se salta la revisión humana.
    _cambiar_estado(rid, "revisada", "publicada")


def rechazar(rid):
    filas = _req("DELETE", f"/rest/v1/reglas?id=eq.{rid}&estado_revision=in.(borrador,revisada)",
                 prefer="return=representation")
    if not filas:
        sys.exit(f"[✗] No se borró nada (¿publicada o inexistente? las publicadas no se borran aquí).")
    print(f"[✓] Regla {rid} descartada.")


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    cmd = a[0]
    if cmd == "insertar" and len(a) == 2:
        insertar(a[1])
    elif cmd == "listar":
        estado = a[a.index("--estado") + 1] if "--estado" in a else None
        listar(estado)
    elif cmd == "revisar" and len(a) == 2:
        revisar(a[1])
    elif cmd == "publicar" and len(a) == 2:
        publicar(a[1])
    elif cmd == "rechazar" and len(a) == 2:
        rechazar(a[1])
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
