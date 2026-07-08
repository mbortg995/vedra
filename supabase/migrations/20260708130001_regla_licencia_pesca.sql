-- Datos · Regla: la licencia de pesca continental es OBLIGATORIA (#32)
--
-- Hasta ahora NINGUNA regla exigía la licencia, así que el semáforo nunca pintaba
-- amarillo en pesca por falta de licencia. La obligación NO está en la ORDEN
-- 30/2016 (esa fija periodos hábiles, vedas y tallas), sino en la Ley de Pesca
-- Fluvial de 20 de febrero de 1942, art. 41 (estatal, vigente y de aplicación en
-- aguas continentales; la propia GVA la lista como normativa del trámite de la
-- licencia de pesca continental). La expedición en la CV se rige por el Decreto
-- 152/1990.
--
-- efecto=requiere + regla_requisitos -> tipo_requisito 'licencia_pesca_cv'.
-- PUBLICADA: llega al usuario y, sin licencia (o sin sesión), pinta AMARILLO.
-- El cruce fino "verde si la tienes" lo hace el cliente en un PR posterior (#17).

-- Idempotencia: id fijo, se borra antes de reinsertar (regla_requisitos cae en
-- cascada). Así la migración es reaplicable sin duplicar.
delete from reglas where id = 'a0000000-0000-4000-8000-000000000010';

-- Fuente oficial de la obligación (Ley de Pesca Fluvial de 1942, BOE consolidado).
insert into fuentes (id, organismo, url, fecha_publicacion) values
  ('f0000000-0000-4000-8000-000000000010',
   'Jefatura del Estado · Ley de Pesca Fluvial de 20 de febrero de 1942 (BOE núm. 67, de 08/03/1942)',
   'https://www.boe.es/buscar/act.php?id=BOE-A-1942-2205',
   '1942-02-20')
on conflict (id) do update
  set organismo = excluded.organismo,
      url = excluded.url,
      fecha_publicacion = excluded.fecha_publicacion;

-- La regla: pescar en la Comunitat Valenciana requiere licencia (capa permanente).
insert into reglas (id, territorio_id, actividad_id, fuente_id, capa, efecto,
                    parametros, vigencia, detalle, cita, estado_revision)
select 'a0000000-0000-4000-8000-000000000010',
       t.id, a.id, 'f0000000-0000-4000-8000-000000000010',
       'permanente', 'requiere',
       '{}'::jsonb, null,
       'Necesitas la licencia de pesca recreativa en aguas continentales de la Comunitat Valenciana.',
       'Todas las personas que en aguas públicas o privadas tomen parte en el ejercicio de la pesca, '
       'bien sea aisladamente o reunidas en cuadrilla para el manejo de redes y otros artes, deberán '
       'estar individualmente provistas de la correspondiente licencia. (Art. 41)',
       'publicada'
from territorios t, actividades a
where t.codigo = 'CV' and a.slug = 'pesca';

-- Enlace al catálogo de requisitos: la licencia que el usuario podrá declarar (#17).
insert into regla_requisitos (regla_id, tipo_requisito_id)
select 'a0000000-0000-4000-8000-000000000010', tr.id
from tipos_requisito tr
where tr.slug = 'licencia_pesca_cv'
on conflict do nothing;
