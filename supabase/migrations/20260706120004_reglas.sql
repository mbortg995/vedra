-- Fase 1 · REGLAS (tabla estrella) + REGLA_REQUISITOS
-- Unifica las tres capas de normativa (permanente/estacional/diaria) en una sola
-- tabla, discriminadas por `capa` y `efecto`. `parametros` jsonb absorbe lo
-- variable (periodos, kg máximos, horas límite...) sin multiplicar columnas.

create table reglas (
  id              uuid primary key default gen_random_uuid(),
  territorio_id   uuid not null references territorios (id) on delete cascade,
  actividad_id    uuid not null references actividades (id) on delete cascade,
  -- NOT NULL a propósito: la regla de oro exige que TODA regla cite su fuente.
  -- El esquema impide que exista una regla sin respaldo oficial.
  fuente_id       uuid not null references fuentes (id),
  capa            text not null check (capa in ('permanente', 'estacional', 'diaria')),
  efecto          text not null
                  check (efecto in ('requiere', 'prohibe', 'limita', 'condicional')),
  parametros      jsonb not null default '{}'::jsonb,
  vigencia        daterange,     -- null = siempre vigente (capa permanente)
  detalle         text,          -- texto legible que la app muestra
  estado_revision text not null default 'borrador'
                  check (estado_revision in ('borrador', 'revisada', 'publicada')),
  creado_en       timestamptz not null default now()
);

create index reglas_territorio_idx on reglas (territorio_id);
create index reglas_actividad_idx  on reglas (actividad_id);

-- Consulta caliente del motor: reglas publicadas de una actividad en unos
-- territorios. Índice parcial -> solo indexa lo que llega al usuario.
create index reglas_lookup_idx
  on reglas (actividad_id, territorio_id)
  where estado_revision = 'publicada';

-- Solapes de vigencia (vedas estacionales) resueltos con índice de rango GIST.
create index reglas_vigencia_gist on reglas using gist (vigencia);

-- Qué requisitos exige una regla (M:N con el catálogo TIPOS_REQUISITO).
create table regla_requisitos (
  regla_id          uuid not null references reglas (id) on delete cascade,
  tipo_requisito_id uuid not null references tipos_requisito (id),
  primary key (regla_id, tipo_requisito_id)
);

comment on column reglas.fuente_id is 'NOT NULL: ninguna regla existe sin fuente oficial (regla de oro).';
comment on column reglas.estado_revision is 'Solo las ''publicada'' llegan al usuario.';
comment on column reglas.parametros is 'jsonb: periodo, kg_max_dia, hasta_hora, solo_si_preemergencia...';
