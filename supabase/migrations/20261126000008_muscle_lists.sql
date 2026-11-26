-- An exercise can work several muscle groups, and several parts of each:
-- muscles holds the groups, sub_muscles the parts (each part's group is in
-- muscles; a group with none of its parts listed means the whole group).
-- Values and order are ProgramStore's muscle tree. "Full body" is no longer a
-- group: those exercises list the groups they work.

alter table public.exercises
    add column muscles text[] not null default '{}',
    add column sub_muscles text[] not null default '{}';

update public.exercises
set muscles = array[muscle],
    sub_muscles = case when sub_muscle = '' then '{}' else array[sub_muscle] end;

-- Built-in exercises: the main groups and parts each one works
update public.exercises e set muscles = v.muscles, sub_muscles = v.parts
from (values
    ('Barbell bench press',    '{Chest,Shoulders,Arms}'::text[], '{Middle Chest,Front Delt,Triceps}'::text[]),
    ('Push-up',                '{Chest,Arms}',                   '{Middle Chest,Triceps}'),
    ('Incline dumbbell press', '{Chest,Shoulders}',              '{Upper Chest,Front Delt}'),
    ('Pull-up',                '{Back,Arms}',                    '{Lats,Biceps}'),
    ('Barbell row',            '{Back,Arms}',                    '{Lats,Biceps}'),
    ('Lat pulldown',           '{Back,Arms}',                    '{Lats,Biceps}'),
    ('Seated cable row',       '{Back,Arms}',                    '{Lats,Biceps}'),
    ('One-arm dumbbell row',   '{Back,Arms}',                    '{Lats,Biceps}'),
    ('Back squat',             '{Legs}',                         '{Quads,Glutes}'),
    ('Goblet squat',           '{Legs}',                         '{Quads,Glutes}'),
    ('Romanian deadlift',      '{Back,Legs}',                    '{Lower Back,Hamstrings,Glutes}'),
    ('Walking lunge',          '{Legs}',                         '{Quads,Glutes}'),
    ('Leg press',              '{Legs}',                         '{Quads,Glutes}'),
    ('Bulgarian split squat',  '{Legs}',                         '{Quads,Glutes}'),
    ('Hip thrust',             '{Legs}',                         '{Hamstrings,Glutes}'),
    ('Kettlebell swing',       '{Back,Legs}',                    '{Lower Back,Hamstrings,Glutes}'),
    ('Overhead press',         '{Shoulders,Arms}',               '{Front Delt,Triceps}'),
    ('Hammer curl',            '{Arms}',                         '{Brachialis,Forearm}'),
    ('Deadlift',               '{Back,Legs}',                    '{Upper Traps,Lower Back,Hamstrings,Glutes}'),
    ('Burpee',                 '{Chest,Legs,Cardio}',            '{Quads}'),
    ('Dumbbell thruster',      '{Legs,Shoulders}',               '{Quads,Glutes,Front Delt}')
) as v (name, muscles, parts)
where e.coach_id is null and e.name = v.name;

-- Drop Full body from anything not listed above (none expected). An exercise
-- left with no group then fails the check below instead of being guessed at.
update public.exercises set muscles = array_remove(muscles, 'Full body');

alter table public.exercises
    drop column muscle,
    drop column sub_muscle,
    add constraint exercises_has_muscle check (cardinality(muscles) > 0);
