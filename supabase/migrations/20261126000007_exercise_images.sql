-- Each exercise can have a drawing: the id of an Open Exercise Art drawing
-- (third_party/open-exercise-art), shipped in the app as
-- assets/exercises/{light,dark}/<image>.png. '' = no drawing (custom
-- exercises, and Dumbbell thruster, which the set doesn't have).

alter table public.exercises add column image text not null default '';

update public.exercises e set image = v.image
from (values
    ('Barbell bench press',    'bench-press'),
    ('Push-up',                'push-up'),
    ('Incline dumbbell press', 'incline-dumbbell-press'),
    ('Cable fly',              'cable-fly'),
    ('Pull-up',                'pull-up'),
    ('Barbell row',            'barbell-row'),
    ('Lat pulldown',           'lat-pulldown'),
    ('Seated cable row',       'seated-cable-row'),
    ('One-arm dumbbell row',   'dumbbell-row'),
    ('Back squat',             'back-squat'),
    ('Goblet squat',           'goblet-squat'),
    ('Romanian deadlift',      'romanian-deadlift'),
    ('Walking lunge',          'walking-lunge'),
    ('Leg press',              'leg-press'),
    ('Bulgarian split squat',  'bulgarian-split-squat'),
    ('Hip thrust',             'hip-thrust'),
    ('Glute bridge',           'glute-bridge'),
    ('Kettlebell swing',       'kettlebell-swing'),
    ('Overhead press',         'overhead-press'),
    ('Lateral raise',          'lateral-raise'),
    ('Face pull',              'face-pull'),
    ('Dumbbell biceps curl',   'bicep-curl'),
    ('Hammer curl',            'hammer-curl'),
    ('Triceps rope pushdown',  'rope-triceps-pushdown'),
    ('Plank',                  'plank'),
    ('Dead bug',               'dead-bug'),
    ('Pallof press',           'pallof-press'),
    ('Hanging knee raise',     'hanging-knee-raise'),
    ('Deadlift',               'deadlift'),
    ('Burpee',                 'burpee'),
    ('Rowing machine',         'rowing'),
    ('Air bike',               'assault-bike'),
    ('Jump rope',              'skipping')
) as v (name, image)
where e.coach_id is null and e.name = v.name;
