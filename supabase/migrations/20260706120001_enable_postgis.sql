-- Fase 1 · Extensiones
-- PostGIS es el corazón espacial: la consulta central de Vedra es
-- "¿qué territorios contienen este punto GPS?" vía ST_Contains subiendo el árbol.
--
-- Convención Supabase: las extensiones viven en el esquema `extensions`, no en
-- `public`. Por eso las columnas de geometría se declaran como
-- `extensions.geometry(...)` en las migraciones siguientes.

create schema if not exists extensions;

create extension if not exists postgis with schema extensions;
