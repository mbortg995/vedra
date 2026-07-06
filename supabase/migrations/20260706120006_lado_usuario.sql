-- Fase 1 · Lado usuario: USUARIOS, LICENCIAS_USUARIO, ZONAS_SEGUIDAS
-- Deliberadamente pequeño. El cruce con licencias es lo único que personaliza la
-- respuesta; todo lo demás es cacheable e igual para todos.

create table usuarios (
  id           uuid primary key default gen_random_uuid(),  -- en prod: = auth.users.id
  plan         text not null default 'gratis' check (plan in ('gratis', 'premium')),
  actividades  jsonb not null default '[]'::jsonb,           -- actividades de interés
  creado_en    timestamptz not null default now()
);

-- Licencias/permisos que el usuario declara tener, con su vencimiento (alimenta
-- los avisos de caducidad). Conectada al MISMO catálogo que usan las reglas.
create table licencias_usuario (
  id                 uuid primary key default gen_random_uuid(),
  usuario_id         uuid not null references usuarios (id) on delete cascade,
  tipo_requisito_id  uuid not null references tipos_requisito (id),
  vence              date,
  creado_en          timestamptz not null default now()
);

create index licencias_usuario_idx on licencias_usuario (usuario_id);

-- Zonas que el usuario sigue -> alimenta notificaciones (vedas, cambios de riesgo).
create table zonas_seguidas (
  usuario_id     uuid not null references usuarios (id) on delete cascade,
  territorio_id  uuid not null references territorios (id) on delete cascade,
  creado_en      timestamptz not null default now(),
  primary key (usuario_id, territorio_id)
);

comment on column usuarios.id is
  'En producción refleja auth.users.id de Supabase Auth; las RLS se atan a auth.uid().';

-- NOTA DE SEGURIDAD (pendiente Fase 3/4): antes de exponer estas tablas por la
-- API de Supabase hay que activar Row Level Security y políticas:
--   - Lectura pública de datos normativos (territorios, reglas publicadas, ...).
--   - Acceso a licencias_usuario / zonas_seguidas SOLO para su dueño (auth.uid()).
