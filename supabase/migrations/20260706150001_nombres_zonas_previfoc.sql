-- Fase 5 · Nombres reales de las 7 zonas Previfoc.
-- El histórico oficial (/Meteorologia/NivelPreemergenciaList) usa estas 7 zonas,
-- en este orden (ZonaID 1..7). Alineamos los códigos CV-PREF-Z1..Z7 con ellas
-- para que la ingesta mapee por posición sin ambigüedad. La GEOMETRÍA sigue
-- siendo provisional (bandas); esto solo corrige el nombre.

update territorios set nombre = 'Zona 1 Norte (geometría provisional)'  where codigo = 'CV-PREF-Z1';
update territorios set nombre = 'Zona 1 Sur (geometría provisional)'    where codigo = 'CV-PREF-Z2';
update territorios set nombre = 'Zona 2 (geometría provisional)'        where codigo = 'CV-PREF-Z3';
update territorios set nombre = 'Zona 3 (geometría provisional)'        where codigo = 'CV-PREF-Z4';
update territorios set nombre = 'Zona 4 (geometría provisional)'        where codigo = 'CV-PREF-Z5';
update territorios set nombre = 'Zona 5 (geometría provisional)'        where codigo = 'CV-PREF-Z6';
update territorios set nombre = 'Zona 6 (geometría provisional)'        where codigo = 'CV-PREF-Z7';
