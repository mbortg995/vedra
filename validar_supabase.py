"""
Validación en vivo del motor contra Supabase (datos reales del proyecto).

A diferencia de `motor.py` (5 casos deterministas en memoria), esto ejerce la
misma lógica del semáforo leyendo por REST: territorios vía RPC espacial, reglas
publicadas, condiciones diarias. Carga las variables del .env local.

    python3 validar_supabase.py
"""

import os
from datetime import date

# Carga simple del .env local (sin dependencias).
_envp = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
if os.path.exists(_envp):
    for _line in open(_envp):
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _k, _v = _line.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

from datos import DatosSupabase
from motor import evaluar, pinta

ds = DatosSupabase()          # usa SUPABASE_URL + SUPABASE_ANON_KEY
hoy = date.today()
LAT, LON = 39.9864, -0.0513   # punto real de Castelló

print("Territorios que resuelve el punto (RPC espacial contra PostGIS):")
for t in ds.territorios_que_contienen(LAT, LON):
    print(f"  - {t['codigo']:<12} {t['nivel']:<10} {t['nombre']}")

pinta("Supabase · Fuego en Castelló hoy (sin dato de preemergencia -> rojo por seguridad)",
      evaluar(ds, "fuego_recreativo", LAT, LON, hoy))

pinta("Supabase · Setas en Castelló hoy (sin reglas publicadas -> verde sin avisos)",
      evaluar(ds, "setas", LAT, LON, hoy))

pinta("Supabase · Fuego en Madrid (fuera de la CV -> igualmente rojo, sin dato)",
      evaluar(ds, "fuego_recreativo", 40.42, -3.70, hoy))
