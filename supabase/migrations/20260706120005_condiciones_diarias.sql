-- Fase 1 · CONDICIONES_DIARIAS
-- Única tabla con escrituras frecuentes (cron matinal de ingesta). Guarda el
-- estado del día por territorio (p. ej. nivel de preemergencia de incendios).
--
-- `obtenido_en` implementa la política de frescura del motor: si el dato es más
-- viejo que el umbral, el semáforo cae a ROJO. Nunca verde por dato caduco.
--
-- PK (territorio_id, fecha, tipo): coincide con el on_conflict del pipeline de
-- ingesta -> un UPSERT reescribe el dato del día sin duplicar.

create table condiciones_diarias (
  territorio_id  uuid not null references territorios (id) on delete cascade,
  fecha          date not null,
  tipo           text not null,          -- 'preemergencia_incendios'
  nivel          text not null,          -- '1' | '2' | '3'
  obtenido_en    timestamptz not null,   -- cuándo se capturó (frescura)
  fuente_url     text,
  primary key (territorio_id, fecha, tipo)
);

create index condiciones_fecha_idx on condiciones_diarias (fecha);

comment on column condiciones_diarias.obtenido_en is
  'Marca de frescura: si es demasiado viejo, el motor degrada a rojo por seguridad.';
