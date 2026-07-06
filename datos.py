"""
Capa de acceso a datos del motor. Aísla de dónde salen territorios, reglas,
condiciones diarias y licencias, para que la lógica del semáforo (motor.py) no
sepa si vienen de diccionarios en memoria o de Supabase.

Dos proveedores con la misma interfaz:
  - DatosMemoria:  diccionarios en memoria. Determinista y offline -> tests.
  - DatosSupabase: lee por la API REST (PostgREST) del proyecto. Solo stdlib.

Interfaz (lo que espera motor.py):
  territorios_que_contienen(lat, lon) -> [ {id, nivel, nombre, ...}, ... ]  (mayor a menor)
  reglas_actividad(actividad)         -> [ regla, ... ]  (dicts con territorio/capa/efecto/...)
  condicion_diaria(territorio_id, fecha) -> condicion | None
  licencias(usuario_id)               -> set(slugs de requisito que tiene el usuario)
"""

import os
import json
import urllib.request
import urllib.parse
from datetime import datetime, date, timezone


# ---------------------------------------------------------------------------
# Proveedor en memoria (diccionarios). Datos simulados para pruebas.
# ---------------------------------------------------------------------------

class DatosMemoria:
    def __init__(self):
        # Cadena de territorios que contiene el punto (simulada: interior de Castelló).
        self._cadena = [
            {"id": "cv",   "nivel": "ccaa",      "nombre": "Comunitat Valenciana"},
            {"id": "z4",   "nivel": "zona_pref", "nombre": "Zona 4 - Interior Norte de Castelló"},
            {"id": "arec", "nivel": "area",      "nombre": "Àrea recreativa Penyagolosa"},
        ]
        self.REGLAS = {
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
        self.CONDICIONES_DIARIAS = {
            ("cv", date(2026, 7, 6)): {
                "tipo": "preemergencia_incendios", "nivel": "1",
                "obtenido_en": datetime(2026, 7, 6, 7, 12, tzinfo=timezone.utc),
                "fuente": {"organismo": "GVA / AEMET", "url": "https://prevencionincendiosgva.es/Meteorology/NivelPreemergencia"},
            },
        }
        self.LICENCIAS_USUARIO = {
            "user-con-todo": {"usar_paellero_habilitado"},
            "user-sin-nada": set(),
        }

    def territorios_que_contienen(self, lat, lon):
        return [dict(t) for t in self._cadena]

    def reglas_actividad(self, actividad):
        return self.REGLAS.get(actividad, [])

    def condicion_diaria(self, territorio_id, fecha):
        return self.CONDICIONES_DIARIAS.get((territorio_id, fecha))

    def licencias(self, usuario_id):
        return self.LICENCIAS_USUARIO.get(usuario_id, set())


# ---------------------------------------------------------------------------
# Proveedor Supabase (REST / PostgREST). Solo biblioteca estándar.
# ---------------------------------------------------------------------------

class DatosSupabase:
    def __init__(self, url=None, key=None, timeout=20):
        self.url = (url or os.environ.get("SUPABASE_URL", "")).rstrip("/")
        # anon para lectura pública; service_role solo en procesos de confianza.
        self.key = key or os.environ.get("SUPABASE_ANON_KEY") or os.environ.get("SUPABASE_SERVICE_KEY", "")
        self.timeout = timeout
        if not (self.url and self.key):
            raise RuntimeError("Faltan SUPABASE_URL / SUPABASE_ANON_KEY en el entorno.")
        self._actividad_ids = None

    # --- helpers REST ---
    def _headers(self):
        return {"apikey": self.key, "Authorization": f"Bearer {self.key}",
                "Content-Type": "application/json"}

    def _get(self, tabla, params):
        q = urllib.parse.urlencode(params, safe="().,*:")
        req = urllib.request.Request(f"{self.url}/rest/v1/{tabla}?{q}", headers=self._headers())
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            return json.loads(r.read().decode())

    def _rpc(self, nombre, body):
        data = json.dumps(body).encode()
        req = urllib.request.Request(f"{self.url}/rest/v1/rpc/{nombre}", data=data,
                                     headers=self._headers(), method="POST")
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            return json.loads(r.read().decode())

    # --- interfaz ---
    def territorios_que_contienen(self, lat, lon):
        return self._rpc("territorios_en_punto", {"lat": lat, "lon": lon})

    def _actividad_id(self, slug):
        if self._actividad_ids is None:
            filas = self._get("actividades", {"select": "id,slug"})
            self._actividad_ids = {f["slug"]: f["id"] for f in filas}
        return self._actividad_ids.get(slug)

    def reglas_actividad(self, actividad):
        aid = self._actividad_id(actividad)
        if not aid:
            return []
        # La RLS garantiza que solo llegan reglas 'publicada'.
        filas = self._get("reglas", {
            "select": "territorio_id,capa,efecto,parametros,detalle,vigencia,"
                      "fuentes(organismo,url,fecha_publicacion),"
                      "regla_requisitos(tipos_requisito(slug))",
            "actividad_id": f"eq.{aid}",
        })
        reglas = []
        for f in filas:
            regla = {
                "territorio": f["territorio_id"],
                "capa": f["capa"], "efecto": f["efecto"],
                "detalle": f.get("detalle"),
                "parametros": f.get("parametros") or {},
                "fuente": self._fuente(f.get("fuentes")),
            }
            if f["efecto"] == "requiere":
                reqs = [x["tipos_requisito"]["slug"]
                        for x in (f.get("regla_requisitos") or []) if x.get("tipos_requisito")]
                regla["requisito"] = reqs[0] if reqs else None
            reglas.append(regla)
        return reglas
        # TODO(vigencia): filtrar reglas estacionales por fecha cuando haya reglas publicadas.

    def condicion_diaria(self, territorio_id, fecha):
        f = fecha.isoformat() if hasattr(fecha, "isoformat") else fecha
        filas = self._get("condiciones_diarias", {
            "select": "tipo,nivel,obtenido_en,fuente_url",
            "territorio_id": f"eq.{territorio_id}",
            "fecha": f"eq.{f}",
            "tipo": "eq.preemergencia_incendios",
            "limit": "1",
        })
        if not filas:
            return None
        c = filas[0]
        return {
            "tipo": c["tipo"], "nivel": c["nivel"],
            "obtenido_en": self._parse_dt(c["obtenido_en"]),
            "fuente": {"organismo": "GVA / AEMET", "url": c.get("fuente_url")},
        }

    def licencias(self, usuario_id):
        # Las licencias son owner-only (RLS): el cruce se hace en la capa
        # autenticada/cliente, no con la clave anon. Aquí, sin sesión, no hay licencias.
        return set()

    # --- utilidades ---
    @staticmethod
    def _fuente(f):
        if not f:
            return None
        return {"organismo": f.get("organismo"), "url": f.get("url"), "fecha": f.get("fecha_publicacion")}

    @staticmethod
    def _parse_dt(s):
        if s and s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.fromisoformat(s)
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
