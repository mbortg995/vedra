-- Datos · Normativa de recolección de setas en la CV (#19)
--
-- Fuente oficial: Orden de 16 de septiembre de 1996, de la Conselleria de
-- Agricultura y Medio Ambiente, por la que se regula la recolección de setas y
-- otros hongos en el territorio de la Comunidad Valenciana (DOGV 15/11/1996).
-- Cuatro reglas `limita` (permanentes, territorio CV, publicadas). El motor las
-- muestra como AVISOS informativos: setas queda verde + avisos (salvo que la
-- preemergencia sea nivel 3, que la afecta y la pone en rojo por otra vía).
--
-- Antes solo había una regla de ejemplo ('[EJEMPLO]', revisada, 10 kg) que
-- nunca llegó al usuario; se elimina al sustituirla por la normativa real.

-- Limpieza: quita la regla de ejemplo de setas y las reales previas (idempotente).
delete from reglas r using actividades a
where r.actividad_id = a.id and a.slug = 'setas' and r.detalle like '[EJEMPLO]%';
delete from reglas where id in (
  'a0000000-0000-4000-8000-000000000020',
  'a0000000-0000-4000-8000-000000000021',
  'a0000000-0000-4000-8000-000000000022',
  'a0000000-0000-4000-8000-000000000023'
);

-- Fuente oficial (Orden de 16/09/1996).
insert into fuentes (id, organismo, url, fecha_publicacion) values
  ('f0000000-0000-4000-8000-000000000020',
   'GVA · Conselleria de Agricultura y Medio Ambiente — Orden de 16 de septiembre de 1996 (recolección de setas y hongos; DOGV 15/11/1996)',
   'https://noticias.juridicas.com/base_datos/CCAA/va-o160996-ama.html',
   '1996-09-16')
on conflict (id) do update
  set organismo = excluded.organismo,
      url = excluded.url,
      fecha_publicacion = excluded.fecha_publicacion;

-- Las cuatro reglas (limita/permanente/CV/publicada), cada una con su artículo.
insert into reglas (id, territorio_id, actividad_id, fuente_id, capa, efecto,
                    parametros, vigencia, detalle, cita, estado_revision)
select v.id, t.id, a.id, 'f0000000-0000-4000-8000-000000000020',
       'permanente', 'limita', v.parametros::jsonb, null, v.detalle, v.cita, 'publicada'
from territorios t, actividades a,
  (values
    ('a0000000-0000-4000-8000-000000000020',
     '{"kg_max_dia": 6}',
     'Máximo 6 kg por persona y día (uso recreativo/autoconsumo). Por encima es aprovechamiento forestal y necesita autorización.',
     'Se podrán recolectar como máximo seis kilogramos por persona y día. Por encima de esta cantidad se considera aprovechamiento forestal de setas y otros hongos y queda regulado por la Ley 3/1993, de 9 de diciembre, Forestal de la Comunidad Valenciana, y su reglamento de aplicación, Decreto 98/1995, de 16 de mayo. (Art. 6)'),
    ('a0000000-0000-4000-8000-000000000021',
     '{}',
     'Prohibida la recogida de noche, desde el ocaso hasta el amanecer.',
     'Se prohíbe la recogida durante la noche, desde la puesta del sol (ocaso) hasta el amanecer (orto). (Art. 8)'),
    ('a0000000-0000-4000-8000-000000000022',
     '{}',
     'Transporta las setas en cesta o recipiente que deje caer las esporas (favorece su dispersión).',
     'A fin de favorecer la dispersión de las esporas de estas especies, el transporte se realizará en cestas u otros recipientes que permitan la caída al exterior de las esporas. (Art. 7)'),
    ('a0000000-0000-4000-8000-000000000023',
     '{}',
     'Corta los ejemplares por la base con navaja (hoja ≤ 11 cm) dejando el micelio; no los arranques.',
     'Se utilizará exclusivamente navaja o similar cuya hoja no exceda de 11 centímetros de longitud. Se cortarán los ejemplares adultos por su base, dejando el micelio en su lugar. (Art. 4)')
  ) as v(id, parametros, detalle, cita)
where t.codigo = 'CV' and a.slug = 'setas';
