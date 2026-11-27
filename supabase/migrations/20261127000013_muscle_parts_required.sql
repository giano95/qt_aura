-- Every muscle group an exercise works now names at least one of its parts
-- (Cardio has no parts). Two built-ins listed a group alone; they get parts.
-- The parts are also in Exercise::muscleTree() (C++): change both together.

update public.exercises set sub_muscles = '{Middle Chest,Quads}'
where coach_id is null and name = 'Burpee';

update public.exercises set sub_muscles = '{Upper Abs,Lower Abs}'
where coach_id is null and name = 'Plank';

alter table public.exercises add constraint exercises_parts_per_muscle check (
        ('Chest' <> all (muscles)     or sub_muscles && '{Upper Chest,Middle Chest,Lower Chest}')
    and ('Back' <> all (muscles)      or sub_muscles && '{Upper Traps,Lower Traps,Lats,Lower Back}')
    and ('Legs' <> all (muscles)      or sub_muscles && '{Quads,Hamstrings,Glutes,Abductors,Adductors,Calves}')
    and ('Shoulders' <> all (muscles) or sub_muscles && '{Front Delt,Middle Delt,Rear Delt}')
    and ('Arms' <> all (muscles)      or sub_muscles && '{Biceps,Brachialis,Triceps,Forearm}')
    and ('Abs' <> all (muscles)       or sub_muscles && '{Upper Abs,Lower Abs,Obliques}')
);
