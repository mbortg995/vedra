-- Fase 4 · RPC espacial: territorios que contienen un punto GPS.
--
-- El motor necesita la consulta central ST_Contains(geom, punto), pero PostgREST
-- no ejecuta PostGIS en el cliente. Se expone como función RPC, llamable por REST:
--   POST /rest/v1/rpc/territorios_en_punto  {"lat": 39.9864, "lon": -0.0513}
--
-- Devuelve la cadena de territorios de mayor a menor (CCAA -> zona -> área),
-- ordenada por área descendente. SECURITY INVOKER (por defecto): respeta la RLS
-- de `territorios` (lectura pública). search_path fija `extensions` para resolver
-- las funciones PostGIS, que viven en ese esquema.

create or replace function public.territorios_en_punto(lat double precision, lon double precision)
returns table (id uuid, codigo text, nivel text, nombre text)
language sql
stable
set search_path = public, extensions
as $$
  select t.id, t.codigo, t.nivel, t.nombre
  from territorios t
  where t.geom is not null
    and ST_Contains(t.geom, ST_SetSRID(ST_MakePoint(lon, lat), 4326))
  order by ST_Area(t.geom) desc
$$;

grant execute on function public.territorios_en_punto(double precision, double precision)
  to anon, authenticated;

comment on function public.territorios_en_punto(double precision, double precision) is
  'Cadena de territorios (mayor a menor) que contienen el punto (lat, lon) WGS84.';
