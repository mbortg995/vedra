-- Fase 4 · Row Level Security (RLS)
--
-- Hasta ahora, con RLS desactivada, el rol `anon` (clave pública) podía leer
-- TODAS las tablas. Esto lo cierra:
--   - Datos normativos: lectura pública, pero de REGLAS solo las 'publicada'
--     (la regla de oro también en la capa de API: los borradores no salen).
--   - Datos de usuario: solo su dueño (auth.uid()).
--   - Escrituras: sin política para `anon` => denegadas. La ingesta escribe con
--     `service_role`, que se salta RLS.

-- 1) Activar RLS en todas las tablas.
alter table territorios         enable row level security;
alter table actividades         enable row level security;
alter table fuentes             enable row level security;
alter table tipos_requisito     enable row level security;
alter table reglas              enable row level security;
alter table regla_requisitos    enable row level security;
alter table condiciones_diarias enable row level security;
alter table usuarios            enable row level security;
alter table licencias_usuario   enable row level security;
alter table zonas_seguidas      enable row level security;

-- 2) Lectura pública de datos de referencia/normativos (anon + authenticated).
create policy "lectura publica territorios"         on territorios         for select using (true);
create policy "lectura publica actividades"         on actividades         for select using (true);
create policy "lectura publica fuentes"             on fuentes             for select using (true);
create policy "lectura publica tipos_requisito"     on tipos_requisito     for select using (true);
create policy "lectura publica regla_requisitos"    on regla_requisitos    for select using (true);
create policy "lectura publica condiciones_diarias" on condiciones_diarias for select using (true);

-- 3) REGLAS: solo las publicadas son públicas. Borrador/revisada quedan ocultas.
create policy "lectura publica reglas publicadas" on reglas
  for select using (estado_revision = 'publicada');

-- 4) Datos de usuario: solo su dueño. auth.uid() es null para anon => denegado.
create policy "usuario ve su ficha" on usuarios
  for select using (auth.uid() = id);

create policy "usuario gestiona sus licencias" on licencias_usuario
  for all using (auth.uid() = usuario_id) with check (auth.uid() = usuario_id);

create policy "usuario gestiona sus zonas seguidas" on zonas_seguidas
  for all using (auth.uid() = usuario_id) with check (auth.uid() = usuario_id);
