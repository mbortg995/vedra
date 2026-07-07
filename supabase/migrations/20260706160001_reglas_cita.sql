-- Fase 7 · Trazabilidad de la curación: cita textual de la norma.
-- Cada regla curada guarda el fragmento LITERAL del documento oficial que la
-- respalda. Refuerza la regla de oro: toda regla se puede citar palabra por
-- palabra, no solo enlazar a la fuente. Facilita la revisión humana.

alter table reglas add column cita text;

comment on column reglas.cita is
  'Fragmento textual del documento oficial que respalda la regla (trazabilidad).';
