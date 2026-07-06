-- Fase 2 · Seed de catálogos: actividades, fuentes, tipos de requisito.
-- Idempotente (ON CONFLICT DO NOTHING) para poder reaplicar sin duplicar.

-- Actividades del MVP (fuego y setas) + las del segundo release (pesca, caza).
insert into actividades (slug, nombre, icono) values
  ('fuego_recreativo', 'Fuego recreativo',        'campfire'),
  ('setas',            'Recolección de setas',    'mushroom'),
  ('pesca',            'Pesca recreativa',         'fish'),
  ('caza',             'Caza',                     'deer')
on conflict (slug) do nothing;

-- Fuentes oficiales (id fijo para poder referenciarlas desde las reglas seed).
insert into fuentes (id, organismo, url, fecha_publicacion) values
  ('f0000000-0000-4000-8000-000000000001',
   'GVA - Prevención de Incendios Forestales',
   'https://prevencionincendiosgva.es/', '2026-06-01'),
  ('f0000000-0000-4000-8000-000000000002',
   'GVA - Medi Natural (Conselleria de Medi Ambient)',
   'https://mediambient.gva.es/', '2026-01-01')
on conflict (id) do nothing;

-- Catálogo de requisitos (el mismo que cruzan reglas y licencias de usuario).
insert into tipos_requisito (slug, nombre, ambito, url_tramite) values
  ('licencia_pesca_cv',        'Licencia de pesca recreativa (Comunitat Valenciana)', 'ccaa',
   'https://mediambient.gva.es/es/web/pesca'),
  ('usar_paellero_habilitado', 'Uso de paellero/barbacoa habilitada',                 'local', null)
on conflict (slug) do nothing;
