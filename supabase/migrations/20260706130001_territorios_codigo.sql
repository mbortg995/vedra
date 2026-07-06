-- Fase 2 · Mejora de esquema descubierta al sembrar datos.
-- `codigo`: clave externa ESTABLE y legible para un territorio (p. ej. 'CV',
-- 'CV-PREF-Z4', o un código INE). Permite:
--   - Mapear las 7 zonas Previfoc que emite la ingesta a filas de TERRITORIOS
--     sin depender de uuids opacos.
--   - Referenciar territorios en seeds y reglas de forma reproducible.
-- Nullable (nodos sin código externo) pero único cuando está presente.

alter table territorios add column codigo text;

create unique index territorios_codigo_uidx
  on territorios (codigo) where codigo is not null;

comment on column territorios.codigo is
  'Clave externa estable (CV, CV-PREF-Z4, código INE...). Única cuando no es null.';
