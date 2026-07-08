-- Datos · Publica la regla del periodo hábil de pesca de trucha (#21)
--
-- La regla estaba en 'borrador' (curada de la ORDEN 30/2016, art. 6 y 7). Se
-- CONTRASTA con la última modificación (Resolución de 16/09/2024, DOGV 21/10/2024):
-- esa resolución solo cambió el tramo del río Cabriel (art. 6.1), la tabla de
-- especies (ya reflejada) y los anexos I/II (desglose de tramos y acotados). NO
-- tocó el periodo general ni los días hábiles. Por tanto el periodo general
-- sigue vigente y se publica.
--
-- Matiz de seguridad: se añade al detalle que tramos y acotados concretos pueden
-- tener periodo o días propios (p. ej. Mijares: mar/jue/sáb/dom), para no inducir
-- a error donde la app aún no distingue por tramo.

-- Quita el borrador previo (id real en la BB.DD.) y la versión publicada anterior
-- (id fijo) para que la migración sea reaplicable sin duplicar.
delete from reglas where id in (
  '90e38424-4c49-4386-844b-03333a5789ba',
  'a0000000-0000-4000-8000-000000000030'
);

insert into reglas (id, territorio_id, actividad_id, fuente_id, capa, efecto,
                    parametros, vigencia, detalle, cita, estado_revision)
select 'a0000000-0000-4000-8000-000000000030',
       t.id, a.id,
       (select id from fuentes
         where url like '%585123-orden-30-2016%' order by creado_en limit 1),
       'estacional', 'limita',
       '{"periodo_habil": "del tercer domingo de marzo al 31 de agosto", "dias_habiles": ["viernes","sábado","domingo","festivos"], "ambito": "aguas trucheras", "excepcion": "Río Chelva/Tuéjar: todo el año"}'::jsonb,
       null,
       'Pesca de trucha (periodo general): del tercer domingo de marzo al 31 de agosto; días hábiles viernes, sábado, domingo y festivos. Río Chelva/Tuéjar, todo el año. Ojo: algunos tramos y acotados tienen periodo o días propios.',
       'El periodo hábil de pesca abarca desde el tercer domingo de marzo hasta el 31 de agosto, salvo el Río Chelva/Tuéjar cuyo periodo abarca todo el año. Los días de pesca son viernes, sábados, domingos y festivos nacionales y autonómicos. (Art. 6 y 7)',
       'publicada'
from territorios t, actividades a
where t.codigo = 'CV' and a.slug = 'pesca';
