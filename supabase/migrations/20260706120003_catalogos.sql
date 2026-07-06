-- Fase 1 · Catálogos: ACTIVIDADES, FUENTES, TIPOS_REQUISITO
-- Tablas pequeñas y estables de las que cuelgan las REGLAS.

-- Qué se puede consultar: pesca, setas, fuego_recreativo, caza...
create table actividades (
  id      uuid primary key default gen_random_uuid(),
  slug    text not null unique,   -- clave estable usada por el motor: 'fuego_recreativo'
  nombre  text not null,
  icono   text
);

-- Fuente oficial de cada regla. La regla de oro: nada sin fuente + fecha.
create table fuentes (
  id                uuid primary key default gen_random_uuid(),
  organismo         text not null,
  url               text,
  fecha_publicacion date,
  creado_en         timestamptz not null default now()
);

-- Catálogo de requisitos (licencias, permisos, condiciones). El MISMO catálogo
-- que referencian las reglas (REGLA_REQUISITOS) y las licencias del usuario
-- (LICENCIAS_USUARIO): así "lo que la regla exige" y "lo que el usuario tiene"
-- hablan el mismo idioma.
create table tipos_requisito (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,  -- 'licencia_pesca_cv', 'usar_paellero_habilitado'
  nombre       text not null,
  ambito       text check (ambito in ('estatal', 'ccaa', 'local')),
  url_tramite  text
);

comment on column actividades.slug is 'Clave estable que usa el motor; no cambiar una vez publicada.';
comment on table fuentes is 'Fuente oficial (organismo + url + fecha) que respalda cada regla.';
