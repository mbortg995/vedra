-- Fase 1 · TERRITORIOS
-- Árbol jerárquico con geometría: España -> CCAA -> provincia -> zona/coto/área,
-- enlazado por `padre_id`. La consulta central es espacial:
--   SELECT ... WHERE ST_Contains(geom, punto)  -- subiendo por padre_id.
--
-- `geom` es nullable a propósito: nodos puramente lógicos de agrupación (p. ej.
-- una raíz "España") pueden no tener geometría. Los nodos consultables sí la tienen.

create table territorios (
  id         uuid primary key default gen_random_uuid(),
  padre_id   uuid references territorios (id) on delete cascade,
  nivel      text not null
             check (nivel in ('pais', 'ccaa', 'provincia', 'comarca',
                              'zona_pref', 'coto', 'area')),
  nombre     text not null,
  geom       extensions.geometry(MultiPolygon, 4326),
  creado_en  timestamptz not null default now()
);

-- Índice espacial GIST: sin él, ST_Contains hace scan secuencial.
create index territorios_geom_gist on territorios using gist (geom);

-- Recorrido del árbol hacia arriba por padre_id.
create index territorios_padre_idx on territorios (padre_id);

comment on table territorios is
  'Árbol de territorios con geometría PostGIS; se recorre hacia arriba por padre_id.';
comment on column territorios.nivel is
  'pais | ccaa | provincia | comarca | zona_pref (zona Previfoc) | coto | area';
