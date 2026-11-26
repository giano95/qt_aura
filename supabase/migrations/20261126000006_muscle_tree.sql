-- Muscle groups become a tree: each exercise has a group (muscle) and,
-- optionally, a part of that group (sub_muscle; '' = the whole group). The
-- values are the ones in ProgramStore (muscleGroups / subMuscles).
-- Glutes moves under Legs, and Core is renamed Abs.

alter table public.exercises add column sub_muscle text not null default '';

update public.exercises set muscle = 'Legs', sub_muscle = 'Glutes' where muscle = 'Glutes';
update public.exercises set muscle = 'Abs' where muscle = 'Core';

-- Parts of the built-in exercises (Plank and the full-body and cardio ones
-- keep the whole group)
update public.exercises e set sub_muscle = v.part
from (values
    ('Barbell bench press',    'Middle Chest'),
    ('Push-up',                'Middle Chest'),
    ('Incline dumbbell press', 'Upper Chest'),
    ('Cable fly',              'Middle Chest'),
    ('Pull-up',                'Lats'),
    ('Barbell row',            'Lats'),
    ('Lat pulldown',           'Lats'),
    ('Seated cable row',       'Lats'),
    ('One-arm dumbbell row',   'Lats'),
    ('Back squat',             'Quads'),
    ('Goblet squat',           'Quads'),
    ('Romanian deadlift',      'Hamstrings'),
    ('Walking lunge',          'Quads'),
    ('Leg press',              'Quads'),
    ('Bulgarian split squat',  'Quads'),
    ('Overhead press',         'Front Delt'),
    ('Lateral raise',          'Middle Delt'),
    ('Face pull',              'Rear Delt'),
    ('Dumbbell biceps curl',   'Biceps'),
    ('Hammer curl',            'Brachialis'),
    ('Triceps rope pushdown',  'Triceps'),
    ('Dead bug',               'Lower Abs'),
    ('Pallof press',           'Obliques'),
    ('Hanging knee raise',     'Lower Abs')
) as v (name, part)
where e.coach_id is null and e.name = v.name;
