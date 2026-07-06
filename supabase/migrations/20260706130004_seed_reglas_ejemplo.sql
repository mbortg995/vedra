-- Fase 2 · Reglas de ejemplo (espejo de las de motor.py).
--
-- IMPORTANTE (regla de oro): estas reglas quedan en estado 'revisada', NO
-- 'publicada'. Solo las 'publicada' llegan al usuario. Mientras la geometría de
-- las zonas sea provisional y estas reglas sean ejemplos, nada de esto puede
-- pintar un semáforo a un usuario real.
--
-- Idempotencia: se borran las reglas de ejemplo previas (por su detalle marcado)
-- antes de reinsertar, para poder reaplicar la migración sin duplicar.

delete from reglas where detalle like '[EJEMPLO]%';

-- Fuego recreativo: capa estacional 'limita'. Solo con preemergencia 1 y hasta
-- las 11:00 h en el periodo de peligro (1 jun - 15 oct).
insert into reglas (territorio_id, actividad_id, fuente_id, capa, efecto,
                    parametros, vigencia, detalle, estado_revision)
select t.id, a.id, 'f0000000-0000-4000-8000-000000000001',
       'estacional', 'limita',
       '{"periodo":["06-01","10-15"],"solo_si_preemergencia":"1","hasta_hora":"11:00"}'::jsonb,
       daterange('2026-06-01', '2026-10-16'),
       '[EJEMPLO] Fuego solo en paellero habilitado, con preemergencia nivel 1 y hasta las 11:00 h.',
       'revisada'
from territorios t, actividades a
where t.codigo = 'CV' and a.slug = 'fuego_recreativo';

-- Setas: capa permanente 'limita'. Máximo orientativo por persona y día.
insert into reglas (territorio_id, actividad_id, fuente_id, capa, efecto,
                    parametros, vigencia, detalle, estado_revision)
select t.id, a.id, 'f0000000-0000-4000-8000-000000000002',
       'permanente', 'limita',
       '{"kg_max_dia": 10}'::jsonb,
       null,
       '[EJEMPLO] Máximo orientativo de 10 kg de setas por persona y día.',
       'revisada'
from territorios t, actividades a
where t.codigo = 'CV' and a.slug = 'setas';
