-- Fase 7 · Actividad 'quema' (quema de residuos vegetales agrícolas/selvícolas).
-- Es distinta del fuego_recreativo (paellero): la regula el Decreto 91/2023
-- (Reglamento de la Ley 3/1993 Forestal de la CV) y se ata a la preemergencia.

insert into actividades (slug, nombre, icono) values
  ('quema', 'Quema de residuos vegetales', 'fire')
on conflict (slug) do nothing;

-- Requisito real de la excepción a la prohibición estacional (uso futuro).
insert into tipos_requisito (slug, nombre, ambito, url_tramite) values
  ('plan_local_quemas', 'Plan local de quemas aprobado (zona de bajo riesgo)', 'local', null)
on conflict (slug) do nothing;
