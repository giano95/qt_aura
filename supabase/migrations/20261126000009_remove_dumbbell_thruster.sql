-- Dumbbell thruster leaves the built-in library. Programs that used it get a
-- Burpee in its place (same sets, reps and rest; no load), so they keep their
-- shape. Touching the programs sends the live update to coach and clients.

with changed as (
    update public.program_entries pe
    set exercise_id = (select id from public.exercises where coach_id is null and name = 'Burpee'),
        load = '',
        weeks = '{}'
    where pe.exercise_id = (select id from public.exercises where coach_id is null and name = 'Dumbbell thruster')
    returning pe.day_id
)
update public.programs p set updated_at = now()
where p.id in (select d.program_id from public.program_days d where d.id in (select day_id from changed));

delete from public.exercises where coach_id is null and name = 'Dumbbell thruster';
