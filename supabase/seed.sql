-- Demo data: the same people, programs and calendar as the Phase 0 prototype.
-- Run once on a fresh database, after the migrations. Every account's
-- password is "password". Dates are relative to today (Europe/Rome).
--
--   coach@aura.app   Giulia Rossi, the coach with clients, programs and a calendar
--   client@aura.app  Luca Bianchi, one of Giulia's clients
--   other coaches and clients: <first>.<last>@example.com

-- Creates a confirmed email/password account; the signup trigger creates the
-- profile (and coach profile)
create function pg_temp.make_user(p_email text, p_name text, p_role text) returns uuid
language plpgsql as $$
declare
    uid uuid := gen_random_uuid();
begin
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', p_email,
            extensions.crypt('password', extensions.gen_salt('bf')), now(),
            '{"provider": "email", "providers": ["email"]}',
            jsonb_build_object('name', p_name, 'role', p_role), now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text,
            jsonb_build_object('sub', uid::text, 'email', p_email, 'email_verified', true),
            'email', now(), now(), now());
    return uid;
end $$;

create function pg_temp.ex(p_name text) returns uuid language sql as $$
    select id from public.exercises where coach_id is null and name = p_name
$$;

create function pg_temp.entry(p_day uuid, p_pos int, p_exercise text, p_sets text, p_reps text,
                              p_rest text, p_load text default '', p_notes text default '',
                              p_weeks jsonb default '{}') returns void
language sql as $$
    insert into public.program_entries (day_id, position, exercise_id, sets, reps, rest, load, notes, weeks)
    values (p_day, p_pos, pg_temp.ex(p_exercise), p_sets, p_reps, p_rest, p_load, p_notes, p_weeks)
$$;

-- Weekly hours: the same range on the given weekdays
create function pg_temp.hours(p_coach uuid, p_days int[], p_start int, p_end int) returns void
language sql as $$
    insert into public.working_hours (coach_id, weekday, start_min, end_min)
    select p_coach, d, p_start, p_end from unnest(p_days) as d
$$;

-- Local date + minutes in Rome as an instant
create function pg_temp.at(p_day date, p_minutes int) returns timestamptz language sql as $$
    select (p_day + make_interval(mins => p_minutes)) at time zone 'Europe/Rome'
$$;

do $$
declare
    today date := (now() at time zone 'Europe/Rome')::date;
    giulia uuid; marco uuid; sofia uuid; alessandro uuid; chiara_l uuid; tommaso uuid;
    p_strength uuid; p_home uuid; p_fatloss uuid; p_glute uuid;
    d uuid;
    deload jsonb := '{"sets": "3", "reps": "5", "load": "Deload · 60%"}';
    test jsonb := '{"sets": "3", "reps": "3", "load": "RPE 9 · test week"}';
    light jsonb := '{"sets": "2", "load": "Deload · 60%"}';
    c record;
    cid uuid;
    offs int; k int; n int; cnt int; first_t int; wd int; day date;
    times int[] := array[540, 660, 900, 990];
    sample_clients text[] := array['Giorgia Marino', 'Matteo Fontana', 'Andrea Gallo', 'Chiara Moretti',
                                   'Luca Bianchi', 'Sara Conti', 'Davide Russo'];
    types text[] := array['Training', 'Weekly check-in', 'Technique session'];
    modes text[] := array['In person', 'Video call'];
    sid int := 0;
    req_day date;
begin
    if exists (select 1 from public.profiles where email = 'coach@aura.app') then
        raise notice 'Demo data already present, nothing to do';
        return;
    end if;

    -- ---- coaches -----------------------------------------------------------
    giulia := pg_temp.make_user('coach@aura.app', 'Giulia Rossi', 'coach');
    marco := pg_temp.make_user('marco.bellini@example.com', 'Marco Bellini', 'coach');
    sofia := pg_temp.make_user('sofia.ricci@example.com', 'Sofia Ricci', 'coach');
    alessandro := pg_temp.make_user('alessandro.neri@example.com', 'Alessandro Neri', 'coach');
    chiara_l := pg_temp.make_user('chiara.lombardi@example.com', 'Chiara Lombardi', 'coach');
    tommaso := pg_temp.make_user('tommaso.galli@example.com', 'Tommaso Galli', 'coach');

    update public.profiles set phone = '+39 02 1234 5678' where id = giulia;
    update public.profiles set phone = '+39 011 555 0101' where id = marco;
    update public.profiles set phone = '+39 02 555 0199' where id = alessandro;
    update public.profiles set phone = '+39 051 555 0177' where id = chiara_l;

    update public.coach_profiles set title = 'Strength & conditioning coach', city = 'Milano',
        online = true, in_person = true, studio = 'Studio Aura · Via Tortona 27, Milano',
        specialties = '{Strength,Weight loss,Habits}',
        bio = 'I help busy people get strong without living in the gym. Three focused sessions a week, a plan that adapts to your life, and weekly check-ins so you never feel on your own.',
        years = 9, certifications = '{NSCA-CSCS,Precision Nutrition Level 1}', languages = '{Italian,English}',
        price_from = 55, accepting = true, visibility = 'public'
    where coach_id = giulia;
    update public.coach_profiles set title = 'Running & endurance coach', city = 'Torino',
        online = true, in_person = true, studio = 'Parco del Valentino, Torino',
        specialties = '{Running,Endurance,Injury prevention}',
        bio = 'From your first 5 km to your first marathon. Training plans built around your schedule, with strength work to keep you injury-free.',
        years = 7, certifications = '{FIDAL Level 2 coach}', languages = '{Italian,English}',
        price_from = 45, accepting = true, visibility = 'public'
    where coach_id = marco;
    update public.coach_profiles set title = 'Nutrition & weight-loss coach', city = 'Roma',
        online = true, in_person = false, studio = '',
        specialties = '{Weight loss,Nutrition,Habits}',
        bio = 'No crash diets. We build eating habits you can keep, one small change a week, with training that fits around them.',
        years = 5, certifications = '{Registered dietitian}', languages = '{Italian}',
        price_from = 35, accepting = true, visibility = 'public'
    where coach_id = sofia;
    update public.coach_profiles set title = 'Powerlifting coach', city = 'Milano',
        online = false, in_person = true, studio = 'Iron Lab · Viale Monza 120, Milano',
        specialties = '{Strength,Powerlifting,Technique}',
        bio = 'Competitive powerlifter and coach. If you want a bigger squat, bench and deadlift, with technique that holds under heavy weight, let''s talk.',
        years = 12, certifications = '{FIPL coach,NSCA-CSCS}', languages = '{Italian,English}',
        price_from = 60, accepting = false, visibility = 'public'
    where coach_id = alessandro;
    update public.coach_profiles set title = 'Mobility & pre/postnatal coach', city = 'Bologna',
        online = true, in_person = true, studio = 'Spazio Movimento · Via Saragozza 40, Bologna',
        specialties = '{Mobility,Pre & postnatal,Pilates}',
        bio = 'Gentle, progressive training for every stage of life: pregnancy, return to exercise after birth, or simply moving without pain.',
        years = 10, certifications = '{Pilates instructor,Pre/postnatal specialist}', languages = '{Italian,English,Spanish}',
        price_from = 50, accepting = true, visibility = 'public'
    where coach_id = chiara_l;
    update public.coach_profiles set title = 'Calisthenics coach', city = 'Firenze',
        online = true, in_person = false, studio = '',
        specialties = '{Bodyweight,Calisthenics,Mobility}',
        bio = 'Your first pull-up, a solid handstand, or just a strong body with no equipment. All training is online, with video feedback on your form.',
        years = 4, certifications = '{Calisthenics instructor}', languages = '{Italian,English}',
        price_from = 30, accepting = true, visibility = 'public'
    where coach_id = tommaso;

    perform pg_temp.hours(giulia, '{1,2,3,4,5}', 540, 1080);
    perform pg_temp.hours(marco, '{1,2,3,4,5}', 420, 780);
    perform pg_temp.hours(marco, '{6}', 480, 720);
    perform pg_temp.hours(sofia, '{1,2,3,4,5}', 600, 1140);
    perform pg_temp.hours(alessandro, '{1,2,3,4,5}', 900, 1260);
    perform pg_temp.hours(chiara_l, '{1,2,3,4,5}', 540, 1020);
    perform pg_temp.hours(tommaso, '{1,2,3,4,5}', 1020, 1260);
    perform pg_temp.hours(tommaso, '{6}', 540, 780);

    -- ---- Giulia's programs -------------------------------------------------
    insert into public.programs (coach_id, name, description, weeks, updated_at) values
        (giulia, 'Strength foundations', 'Three full sessions a week built around the main lifts. For clients with some gym experience.', 8, now() - interval '2 days')
        returning id into p_strength;
    insert into public.programs (coach_id, name, description, weeks, updated_at) values
        (giulia, 'Home training, no equipment', 'Bodyweight sessions for clients who train at home or while travelling.', 6, now() - interval '9 days')
        returning id into p_home;
    insert into public.programs (coach_id, name, description, weeks, updated_at) values
        (giulia, 'Fat loss conditioning', 'Circuit-style sessions with short rests to keep the heart rate up.', 12, now() - interval '20 days')
        returning id into p_fatloss;
    insert into public.programs (coach_id, name, description, weeks, updated_at) values
        (giulia, 'Glute and core focus', 'Draft: lower-body accessory block.', 4, now() - interval '1 day')
        returning id into p_glute;

    insert into public.program_days (program_id, position, name) values (p_strength, 0, 'Day 1 · Lower body') returning id into d;
    perform pg_temp.entry(d, 0, 'Back squat', '4', '6–8', '120', 'RPE 7', 'Add 2.5 kg when all sets hit 8', jsonb_build_object('4', deload, '8', test));
    perform pg_temp.entry(d, 1, 'Romanian deadlift', '3', '8–10', '90', 'RPE 7', '', jsonb_build_object('4', light));
    perform pg_temp.entry(d, 2, 'Walking lunge', '3', '10 per leg', '60', '2 × 12 kg');
    perform pg_temp.entry(d, 3, 'Plank', '3', '45 s', '45', '', '', '{"5": {"reps": "60 s"}, "6": {"reps": "60 s"}, "7": {"reps": "75 s"}, "8": {"reps": "75 s"}}');
    insert into public.program_days (program_id, position, name) values (p_strength, 1, 'Day 2 · Upper body') returning id into d;
    perform pg_temp.entry(d, 0, 'Barbell bench press', '4', '6–8', '120', 'RPE 7', '', jsonb_build_object('4', deload, '8', test));
    perform pg_temp.entry(d, 1, 'Barbell row', '4', '8', '90', 'RPE 7');
    perform pg_temp.entry(d, 2, 'Overhead press', '3', '8', '90', 'RPE 7', '', jsonb_build_object('4', light));
    perform pg_temp.entry(d, 3, 'Face pull', '3', '12–15', '45', 'Light cable');
    insert into public.program_days (program_id, position, name) values (p_strength, 2, 'Day 3 · Full body') returning id into d;
    perform pg_temp.entry(d, 0, 'Deadlift', '3', '5', '150', 'RPE 7', 'Stop 2 reps before failure', jsonb_build_object('4', light));
    perform pg_temp.entry(d, 1, 'Pull-up', '3', 'Max', '120', 'Bodyweight');
    perform pg_temp.entry(d, 2, 'Goblet squat', '3', '10', '60', '16 kg');
    perform pg_temp.entry(d, 3, 'Pallof press', '3', '10 per side', '45');

    insert into public.program_days (program_id, position, name) values (p_home, 0, 'Day 1 · Push and legs') returning id into d;
    perform pg_temp.entry(d, 0, 'Push-up', '4', '10–15', '60', '', '', '{"4": {"reps": "15–20"}, "5": {"reps": "15–20"}, "6": {"reps": "20+"}}');
    perform pg_temp.entry(d, 1, 'Glute bridge', '3', '15', '45');
    perform pg_temp.entry(d, 2, 'Burpee', '3', '10', '60', '', '', '{"5": {"sets": "4"}, "6": {"sets": "4"}}');
    insert into public.program_days (program_id, position, name) values (p_home, 1, 'Day 2 · Core and conditioning') returning id into d;
    perform pg_temp.entry(d, 0, 'Dead bug', '3', '8 per side', '45');
    perform pg_temp.entry(d, 1, 'Plank', '3', '40 s', '30');
    perform pg_temp.entry(d, 2, 'Jump rope', '5', '1 min', '30');

    insert into public.program_days (program_id, position, name) values (p_fatloss, 0, 'Day 1 · Circuit A') returning id into d;
    perform pg_temp.entry(d, 0, 'Kettlebell swing', '4', '15', '30', '16 kg');
    perform pg_temp.entry(d, 1, 'Burpee', '4', '10', '30');
    perform pg_temp.entry(d, 2, 'Rowing machine', '4', '250 m', '60', 'Hard pace');
    insert into public.program_days (program_id, position, name) values (p_fatloss, 1, 'Day 2 · Circuit B') returning id into d;
    perform pg_temp.entry(d, 0, 'Goblet squat', '4', '12', '30', '16 kg');
    perform pg_temp.entry(d, 1, 'One-arm dumbbell row', '4', '10 per arm', '30', '14 kg');
    perform pg_temp.entry(d, 2, 'Air bike', '6', '20 s hard', '40');
    insert into public.program_days (program_id, position, name) values (p_fatloss, 2, 'Day 3 · Steady cardio') returning id into d;
    perform pg_temp.entry(d, 0, 'Rowing machine', '1', '30 min', '0', 'Easy pace', 'Able to talk the whole time');

    insert into public.program_days (program_id, position, name) values (p_glute, 0, 'Day 1') returning id into d;
    perform pg_temp.entry(d, 0, 'Hip thrust', '4', '10', '90', '40 kg');
    perform pg_temp.entry(d, 1, 'Bulgarian split squat', '3', '10 per leg', '60', '2 × 10 kg');

    -- ---- Giulia's clients --------------------------------------------------
    -- program: 's' strength, 'h' home, 'f' fat loss; start/ended in days ago
    for c in
        select * from (values
            ('Luca Bianchi', 'client@aura.app', '+39 333 120 4455', 'Squat his bodyweight by the summer', 'active', 160, 2,
             '[{"p":"h","start":120,"ended":78,"reason":"completed"},{"p":"s","start":33,"note":"Focus on technique for the first two weeks."}]'),
            ('Sara Conti', 'sara.conti@example.com', '+39 347 882 1904', 'Lose 6 kg and feel fitter', 'active', 45, 1,
             '[{"p":"f","start":20}]'),
            ('Marco Ferri', 'marco.ferri@example.com', '+39 320 554 7781', 'Get back into the gym after an injury', 'active', 90, 5,
             '[{"p":"h","start":100,"ended":58,"reason":"completed"},{"p":"s","start":60}]'),
            ('Elena Greco', 'elena.greco@example.com', '+39 351 220 9087', 'Build a routine she can keep', 'active', 3, null,
             '[]'),
            ('Davide Russo', 'davide.russo@example.com', '+39 339 671 2230', 'Run a 10 km under 55 minutes', 'active', 70, 16,
             '[{"p":"h","start":50}]'),
            ('Chiara Moretti', 'chiara.moretti@example.com', '+39 348 909 1123', 'Tone up before her wedding', 'active', 95, 3,
             '[{"p":"f","start":81}]'),
            ('Paolo Romano', 'paolo.romano@example.com', '+39 366 404 5521', 'General fitness, sits at a desk all day', 'active', 1, null,
             '[]'),
            ('Giorgia Marino', 'giorgia.marino@example.com', '+39 340 777 3012', 'Stay active while travelling for work', 'active', 30, 4,
             '[{"p":"h","start":10}]'),
            ('Andrea Gallo', 'andrea.gallo@example.com', '+39 329 118 6640', 'First deadlift over 100 kg', 'active', 12, 6,
             '[{"p":"s","start":-5}]'),
            ('Francesca Costa', 'francesca.costa@example.com', '+39 335 290 8812', 'Return after maternity leave', 'paused', 300, 64,
             '[{"p":"f","start":150,"ended":66,"reason":"ended"}]'),
            ('Matteo Fontana', 'matteo.fontana@example.com', '+39 345 660 1279', 'Improve posture and back pain', 'active', 8, 1,
             '[{"p":"h","start":2}]')
        ) as t(name, email, phone, goal, status, since_ago, check_in_ago, assignments)
    loop
        cid := pg_temp.make_user(c.email, c.name, 'client');
        update public.profiles set phone = c.phone where id = cid;
        insert into public.coachings (id, coach_id, client_id, email, name, goal, phone, status, since, last_check_in)
        values (gen_random_uuid(), giulia, cid, c.email, c.name, c.goal, c.phone, c.status,
                today - c.since_ago, today - c.check_in_ago)
        returning id into cid;
        insert into public.assignments (coaching_id, program_id, program_name, weeks, start_date, note, ended_on, end_reason, created_at)
        select cid, p.id, p.name, p.weeks, today - (a ->> 'start')::int, coalesce(a ->> 'note', ''),
               today - (a ->> 'ended')::int, a ->> 'reason', now() - make_interval(days => (a ->> 'start')::int + 1000)
        from jsonb_array_elements(c.assignments::jsonb) with ordinality as x(a, i)
        join public.programs p on p.id = case a ->> 'p' when 's' then p_strength when 'h' then p_home else p_fatloss end
        order by i;
    end loop;

    -- An invitation to an email without an account (private-profile flow)
    insert into public.coachings (coach_id, email, name, status, since)
    values (giulia, 'laura.ricci@example.com', 'Laura Ricci', 'invited', today - 2);

    -- Two requests waiting for Giulia
    cid := pg_temp.make_user('federico.russo@example.com', 'Federico Russo', 'client');
    insert into public.coachings (coach_id, client_id, email, name, goal, message, status, requested_at)
    values (giulia, cid, 'federico.russo@example.com', 'Federico Russo', 'Get back in shape after two years off',
            'I used to play football. Free on weekday evenings.', 'requested', now() - interval '3 hours');
    cid := pg_temp.make_user('martina.esposito@example.com', 'Martina Esposito', 'client');
    insert into public.coachings (coach_id, client_id, email, name, goal, status, requested_at)
    values (giulia, cid, 'martina.esposito@example.com', 'Martina Esposito', 'Prepare for a hiking trip in the Dolomites',
            'requested', now() - interval '26 hours');

    -- ---- Giulia's calendar -------------------------------------------------
    -- Today
    insert into public.sessions (coach_id, client_id, client_name, client_email, starts_at, ends_at, type, mode, status)
    select giulia, p.id, p.name, p.email, pg_temp.at(today, t.m), pg_temp.at(today, t.m + 60), t.type, t.mode, 'confirmed'
    from (values ('Luca Bianchi', 540, 'Monthly review', 'Video call'),
                 ('Sara Conti', 630, 'Goal setting', 'In person'),
                 ('Marco Ferri', 840, 'Weekly check-in', 'Video call'),
                 ('Elena Greco', 1050, 'First session', 'In person')) as t(name, m, type, mode)
    join public.profiles p on p.name = t.name and p.role = 'client';

    -- Other weekdays, two weeks back and two forward (same pattern as the prototype)
    for offs in -14..14 loop
        continue when offs = 0;
        day := today + offs;
        wd := extract(dow from day)::int;
        continue when wd in (0, 6);
        cnt := 1 + abs(offs * 7 + wd) % 3;
        first_t := abs(offs + wd) % 4;
        for k in 0..cnt - 1 loop
            n := abs(offs * 3 + k * 5 + wd);
            sid := sid + 1;
            insert into public.sessions (coach_id, client_id, client_name, client_email, starts_at, ends_at, type, mode, status)
            select giulia, p.id, p.name, p.email,
                   pg_temp.at(day, times[(first_t + k) % 4 + 1]), pg_temp.at(day, times[(first_t + k) % 4 + 1] + 60),
                   types[n % 3 + 1], modes[sid % 2 + 1], 'confirmed'
            from public.profiles p where p.name = sample_clients[n % 7 + 1] and p.role = 'client';
        end loop;
    end loop;

    -- Blocked: a long lunch next Wednesday, an early finish next Friday
    day := (select min(today + g) from generate_series(1, 10) as g where extract(dow from today + g) = 3);
    insert into public.blocked_slots (coach_id, starts_at)
    select giulia, pg_temp.at(day, m) from generate_series(720, 810, 30) as m;
    day := (select min(today + g) from generate_series(1, 10) as g where extract(dow from today + g) = 5);
    insert into public.blocked_slots (coach_id, starts_at)
    select giulia, pg_temp.at(day, m) from generate_series(900, 1050, 30) as m;

    -- Three booking requests on upcoming weekdays (not Wednesday), at times the
    -- confirmed sessions never use
    req_day := today + 2;
    for c in
        select * from (values
            (1, 'Luca Bianchi', 'Technique session', 720, 90, 'Can we look at my squat depth?', 'In person'),
            (2, 'Sara Conti', 'Weekly check-in', 600, 30, '', 'Video call'),
            (3, 'Matteo Fontana', 'Training', 810, 60, 'Lower back is better, ready to train.', 'In person')
        ) as t(i, name, type, m, minutes, note, mode)
        order by i
    loop
        while extract(dow from req_day) in (0, 3, 6) loop
            req_day := req_day + 1;
        end loop;
        insert into public.sessions (coach_id, client_id, client_name, client_email, starts_at, ends_at,
                                     type, mode, note, status, requested_at)
        select giulia, p.id, p.name, p.email, pg_temp.at(req_day, c.m), pg_temp.at(req_day, c.m + c.minutes),
               c.type, c.mode, c.note, 'pending', now() - make_interval(hours => c.i * 5)
        from public.profiles p where p.name = c.name and p.role = 'client';
        req_day := req_day + 2;
    end loop;
end $$;
