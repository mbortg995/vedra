"""
Vigilancia de fuentes normativas (Fase 7b, parte DETERMINISTA — sin IA).

Detecta si un documento oficial vigilado ha cambiado, comparando el hash del
texto visible con el último conocido. NO interpreta nada: solo dice "esto ha
cambiado, hay que curarlo". La curación (extracción a borrador) la hace Claude
(la routine programada o una sesión), siguiendo curacion.md.

    python3 vigilancia_fuentes.py --check    # informa qué fuentes cambiaron (exit 1 si hay cambios)
    python3 vigilancia_fuentes.py --init     # fija los hashes por primera vez (baseline)
    python3 vigilancia_fuentes.py --update   # refija los hashes al estado actual (tras curar)

Estado (hashes) en curacion/fuentes_vigiladas.json. Solo biblioteca estándar.
"""

import os
import re
import sys
import html
import json
import hashlib
import urllib.request
from datetime import datetime, timezone

ESTADO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "curacion", "fuentes_vigiladas.json")
UA = "Vedra/1.0 (vigilancia normativa; contacto@vedra.app)"


def _normalizar(raw):
    """bytes/str de HTML -> texto visible normalizado (para que el hash sea estable)."""
    if isinstance(raw, bytes):
        try:
            raw = raw.decode("utf-8")
        except UnicodeDecodeError:
            raw = raw.decode("latin-1", errors="replace")
    h = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", raw, flags=re.S | re.I)
    t = html.unescape(re.sub(r"<[^>]+>", " ", h))
    return re.sub(r"\s+", " ", t).strip()


def _texto_visible(url):
    """Descarga y normaliza el texto visible de una URL."""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40) as r:
        return _normalizar(r.read())


def _hash(t):
    return hashlib.sha256(t.encode("utf-8")).hexdigest()


def _cargar():
    return json.load(open(ESTADO, encoding="utf-8"))


def _guardar(d):
    json.dump(d, open(ESTADO, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


def revisar(fijar=False, init=False):
    d = _cargar()
    cambios = []
    for f in d["fuentes"]:
        try:
            h = _hash(_texto_visible(f["url"]))
        except Exception as e:
            # Defensivo: un error de red NO se interpreta como cambio ni pisa el hash.
            print(f"[!] {f['id']}: error al descargar ({e}). No se toca su hash.")
            continue
        if init or fijar:
            f["hash"] = h
            f["revisado_en"] = datetime.now(timezone.utc).isoformat()
            print(f"[=] {f['id']}: hash fijado.")
        elif f.get("hash") != h:
            cambios.append(f["id"])
            print(f"[CAMBIO] {f['id']} — {f['descripcion']}")
            print(f"         {f['url']}")
        else:
            print(f"[ok] {f['id']}: sin cambios.")
    if init or fijar:
        _guardar(d)
    return cambios


def main():
    modo = sys.argv[1] if len(sys.argv) > 1 else "--check"
    if modo == "--init":
        revisar(init=True)
    elif modo == "--update":
        revisar(fijar=True)
    elif modo == "--check":
        cambios = revisar()
        if cambios:
            print(f"\n[!] {len(cambios)} fuente(s) cambiada(s): {cambios}. Requieren curación (a borrador).")
            sys.exit(1)
        print("\n[✓] Sin cambios en las fuentes vigiladas.")
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
