-- Aura schema: tables, row-level security and the functions that hold the
-- business rules. The app reads tables directly (RLS limits what each user
-- sees) and changes anything with rules through the functions below.
--
-- Error codes raised by functions (the app maps them to translated text):
--   not_signed_in, not_a_coach, not_a_client, not_found, not_allowed,
--   coach_not_available, already_has_coach, email_taken, invalid_length,
--   too_soon, too_far, slot_unavailable, too_late_to_cancel, invalid_hours,
--   invalid_program, exercise_in_use

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- One row per account (auth.users), created by a trigger at signup
create table public.profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    role        text not null check (role in ('coach', 'client')),
    name        text not null,
    email       text not null unique,
    phone       text not null default '',
    created_at  timestamptz not null default now()
);

-- The public side of a coach account (directory card, booking settings)
create table public.coach_profiles (
    coach_id        uuid primary key references public.profiles (id) on delete cascade,
    title           text not null default '',
    city            text not null default '',
    online          boolean not null default true,
    in_person       boolean not null default false,
    studio          text not null default '',
    specialties     text[] not null default '{}',
    bio             text not null default '',
    years           int not null default 0,
    certifications  text[] not null default '{}',
    languages       text[] not null default '{}',
    price_from      int,
    accepting       boolean not null default true,
    visibility      text not null default 'private' check (visibility in ('public', 'private')),
    timezone        text not null default 'Europe/Rome'
);

-- A coach and a client working together, from request or invitation onwards.
-- client_id is null for an invitation to an email that has no account yet;
-- the signup trigger fills it in.
--   requested: the client asked a public coach, waiting for the coach
--   invited:   a private coach invited the email, waiting for the client
--   active / paused: working together
--   declined:  the coach declined the request (the client sees it until dismissed)
--   ended:     the client left
create table public.coachings (
    id             uuid primary key default gen_random_uuid(),
    coach_id       uuid not null references public.profiles (id) on delete cascade,
    client_id      uuid references public.profiles (id) on delete cascade,
    email          text not null check (email = lower(email)),
    name           text not null,
    goal           text not null default '',
    message        text not null default '',
    phone          text not null default '',
    status         text not null check (status in ('requested', 'invited', 'active', 'paused', 'declined', 'ended')),
    since          date not null default current_date,
    requested_at   timestamptz not null default now(),
    last_check_in  date,
    ended_at       timestamptz
);
-- A client has at most one open coaching
create unique index coachings_one_open_per_email on public.coachings (email)
    where status in ('requested', 'invited', 'active', 'paused');
create index coachings_coach_idx on public.coachings (coach_id);
create index coachings_client_idx on public.coachings (client_id);

-- Exercise library. coach_id null = built-in, read-only for everyone.
create table public.exercises (
    id            uuid primary key default gen_random_uuid(),
    coach_id      uuid references public.profiles (id) on delete cascade,
    name          text not null,
    muscle        text not null,
    equipment     text not null,
    instructions  text not null default '',
    video_url     text not null default ''
);
create unique index exercises_name_per_owner on public.exercises
    (coalesce(coach_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

create table public.programs (
    id           uuid primary key default gen_random_uuid(),
    coach_id     uuid not null references public.profiles (id) on delete cascade,
    name         text not null,
    description  text not null default '',
    weeks        int not null check (weeks between 1 and 52),
    updated_at   timestamptz not null default now()
);
create index programs_coach_idx on public.programs (coach_id);

create table public.program_days (
    id          uuid primary key default gen_random_uuid(),
    program_id  uuid not null references public.programs (id) on delete cascade,
    position    int not null,
    name        text not null
);
create index program_days_program_idx on public.program_days (program_id);

-- sets/reps/load/rest/notes apply to every week; weeks holds per-week changes
-- of sets/reps/load only: {"4": {"sets": "3", "load": "60%"}}
create table public.program_entries (
    id           uuid primary key default gen_random_uuid(),
    day_id       uuid not null references public.program_days (id) on delete cascade,
    position     int not null,
    exercise_id  uuid not null references public.exercises (id) on delete restrict,
    sets         text not null default '',
    reps         text not null default '',
    load         text not null default '',
    rest         text not null default '',
    notes        text not null default '',
    weeks        jsonb not null default '{}'
);
create index program_entries_day_idx on public.program_entries (day_id);
create index program_entries_exercise_idx on public.program_entries (exercise_id);

-- A program given to a client. Name and length are copied at assignment time.
-- The current assignment is the newest one with ended_on null.
create table public.assignments (
    id            uuid primary key default gen_random_uuid(),
    coaching_id   uuid not null references public.coachings (id) on delete cascade,
    program_id    uuid references public.programs (id) on delete set null,
    program_name  text not null,
    weeks         int not null check (weeks between 1 and 104),
    start_date    date not null,
    note          text not null default '',
    ended_on      date,
    end_reason    text check (end_reason in ('completed', 'replaced', 'ended')),
    created_at    timestamptz not null default now()
);
create index assignments_coaching_idx on public.assignments (coaching_id);
create index assignments_program_idx on public.assignments (program_id);

-- Weekly working hours, in minutes from midnight in the coach's time zone.
-- weekday: 0 = Sunday ... 6 = Saturday
create table public.working_hours (
    coach_id   uuid not null references public.profiles (id) on delete cascade,
    weekday    int not null check (weekday between 0 and 6),
    start_min  int not null check (start_min between 0 and 1410 and start_min % 30 = 0),
    end_min    int not null check (end_min between 30 and 1440 and end_min % 30 = 0),
    check (end_min > start_min),
    primary key (coach_id, weekday, start_min)
);

-- 30-minute slots the coach made unavailable (slot start)
create table public.blocked_slots (
    coach_id   uuid not null references public.profiles (id) on delete cascade,
    starts_at  timestamptz not null,
    primary key (coach_id, starts_at)
);

-- Sessions and booking requests. client_id may be null for sample sessions;
-- client_name / client_email are kept for display.
create table public.sessions (
    id            uuid primary key default gen_random_uuid(),
    coach_id      uuid not null references public.profiles (id) on delete cascade,
    client_id     uuid references public.profiles (id) on delete set null,
    client_name   text not null,
    client_email  text not null default '',
    starts_at     timestamptz not null,
    ends_at       timestamptz not null,
    type          text not null default '',
    mode          text not null default '',
    note          text not null default '',
    status        text not null check (status in ('confirmed', 'pending', 'declined', 'cancelled')),
    requested_at  timestamptz,
    cancelled_by  text check (cancelled_by in ('client', 'coach')),
    check (ends_at > starts_at),
    -- Confirmed and pending sessions of a coach never overlap
    constraint sessions_no_overlap exclude using gist
        (coach_id with =, tstzrange(starts_at, ends_at) with &&)
        where (status in ('confirmed', 'pending'))
);
create index sessions_coach_time_idx on public.sessions (coach_id, starts_at);
create index sessions_client_idx on public.sessions (client_id);

-- ---------------------------------------------------------------------------
-- Helpers used by policies and functions
-- ---------------------------------------------------------------------------

-- The signed-in user and `other` share a coaching (any status)
create function public.is_linked(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (
        select 1 from public.coachings c
        where (c.coach_id = (select auth.uid()) and c.client_id = other)
           or (c.client_id = (select auth.uid()) and c.coach_id = other))
$$;

create function public.is_public_coach(coach uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.coach_profiles p
                   where p.coach_id = coach and p.visibility = 'public')
$$;

-- The signed-in user owns the program, or follows it through an open coaching
create function public.can_read_program(program uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.programs p
                   where p.id = program and p.coach_id = (select auth.uid()))
        or exists (select 1 from public.assignments a
                   join public.coachings c on c.id = a.coaching_id
                   where a.program_id = program
                     and c.client_id = (select auth.uid())
                     and c.status in ('active', 'paused'))
$$;

create function public.coach_tz(coach uuid) returns text
language sql stable security definer set search_path = '' as $$
    select coalesce((select timezone from public.coach_profiles where coach_id = coach), 'Europe/Rome')
$$;

create function public.coach_today(coach uuid) returns date
language sql stable set search_path = '' as $$
    select (now() at time zone public.coach_tz(coach))::date
$$;

-- The signed-in profile, checking its role
create function public.require_role(wanted text) returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare
    me public.profiles;
begin
    select * into me from public.profiles where id = (select auth.uid());
    if me.id is null then
        raise exception 'not_signed_in';
    end if;
    if me.role <> wanted then
        raise exception '%', case when wanted = 'coach' then 'not_a_coach' else 'not_a_client' end;
    end if;
    return me;
end $$;

-- ---------------------------------------------------------------------------
-- Signup: create the profile from the metadata the app sends
-- ({ name, role }), link pending invitations to the new account
-- ---------------------------------------------------------------------------

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
    user_role text := coalesce(new.raw_user_meta_data ->> 'role', 'client');
begin
    if user_role not in ('coach', 'client') then
        raise exception 'invalid role %', user_role;
    end if;
    insert into public.profiles (id, role, name, email)
    values (new.id, user_role,
            coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), split_part(new.email, '@', 1)),
            lower(new.email));
    if user_role = 'coach' then
        insert into public.coach_profiles (coach_id) values (new.id);
    else
        update public.coachings set client_id = new.id
        where email = lower(new.email) and client_id is null;
    end if;
    return new;
end $$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row-level security: who can read what. Writes with rules go through the
-- functions further down (security definer), so most tables have no write
-- policies at all.
-- ---------------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.coach_profiles  enable row level security;
alter table public.coachings       enable row level security;
alter table public.exercises       enable row level security;
alter table public.programs        enable row level security;
alter table public.program_days    enable row level security;
alter table public.program_entries enable row level security;
alter table public.assignments     enable row level security;
alter table public.working_hours   enable row level security;
alter table public.blocked_slots   enable row level security;
alter table public.sessions        enable row level security;

create policy "profiles: self, linked, public coaches" on public.profiles
    for select to authenticated
    using (id = (select auth.uid()) or public.is_linked(id) or public.is_public_coach(id));
create policy "profiles: edit own" on public.profiles
    for update to authenticated
    using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "coach_profiles: public, own, linked" on public.coach_profiles
    for select to authenticated
    using (visibility = 'public' or coach_id = (select auth.uid()) or public.is_linked(coach_id));
create policy "coach_profiles: edit own" on public.coach_profiles
    for update to authenticated
    using (coach_id = (select auth.uid())) with check (coach_id = (select auth.uid()));

create policy "coachings: either side" on public.coachings
    for select to authenticated
    using (coach_id = (select auth.uid()) or client_id = (select auth.uid()));

create policy "exercises: built-in, own, used in readable programs" on public.exercises
    for select to authenticated
    using (coach_id is null or coach_id = (select auth.uid())
           or exists (select 1 from public.program_entries e
                      join public.program_days d on d.id = e.day_id
                      where e.exercise_id = exercises.id and public.can_read_program(d.program_id)));
create policy "exercises: coach adds own" on public.exercises
    for insert to authenticated
    with check (coach_id = (select auth.uid())
                and exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'coach'));
create policy "exercises: coach edits own" on public.exercises
    for update to authenticated
    using (coach_id = (select auth.uid())) with check (coach_id = (select auth.uid()));
create policy "exercises: coach deletes own" on public.exercises
    for delete to authenticated
    using (coach_id = (select auth.uid()));

create policy "programs: readable" on public.programs
    for select to authenticated
    using (public.can_read_program(id));
create policy "programs: coach deletes own" on public.programs
    for delete to authenticated
    using (coach_id = (select auth.uid()));

create policy "program_days: readable" on public.program_days
    for select to authenticated
    using (public.can_read_program(program_id));

create policy "program_entries: readable" on public.program_entries
    for select to authenticated
    using (exists (select 1 from public.program_days d
                   where d.id = day_id and public.can_read_program(d.program_id)));

create policy "assignments: either side" on public.assignments
    for select to authenticated
    using (exists (select 1 from public.coachings c
                   where c.id = coaching_id
                     and (c.coach_id = (select auth.uid()) or c.client_id = (select auth.uid()))));

create policy "working_hours: own, linked, public coaches" on public.working_hours
    for select to authenticated
    using (coach_id = (select auth.uid()) or public.is_linked(coach_id) or public.is_public_coach(coach_id));

-- Clients don't read blocked slots or other clients' sessions; they get busy
-- times without details from coach_busy()
create policy "blocked_slots: own" on public.blocked_slots
    for select to authenticated
    using (coach_id = (select auth.uid()));
create policy "blocked_slots: coach adds own" on public.blocked_slots
    for insert to authenticated
    with check (coach_id = (select auth.uid())
                and exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'coach'));
create policy "blocked_slots: coach removes own" on public.blocked_slots
    for delete to authenticated
    using (coach_id = (select auth.uid()));

create policy "sessions: either side" on public.sessions
    for select to authenticated
    using (coach_id = (select auth.uid()) or client_id = (select auth.uid()));

-- Column-level limits on the direct updates allowed above: role, email and
-- visibility only change through signup / functions
revoke update on public.profiles from anon, authenticated;
grant update (name, phone) on public.profiles to authenticated;
revoke update on public.coach_profiles from anon, authenticated;
grant update (title, city, online, in_person, studio, specialties, bio, years,
              certifications, languages, price_from, accepting, timezone)
    on public.coach_profiles to authenticated;

-- Nothing for signed-out users
revoke all on all tables in schema public from anon;

-- ---------------------------------------------------------------------------
-- Functions: coach <-> client
-- ---------------------------------------------------------------------------

-- Client asks a public coach
create function public.request_coach(p_coach uuid, p_goal text, p_message text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
    new_id uuid;
begin
    if not exists (select 1 from public.coach_profiles
                   where coach_id = p_coach and visibility = 'public' and accepting) then
        raise exception 'coach_not_available';
    end if;
    delete from public.coachings where email = me.email and status = 'declined';
    insert into public.coachings (coach_id, client_id, email, name, goal, message, status)
    values (p_coach, me.id, me.email, me.name, trim(coalesce(p_goal, '')), trim(coalesce(p_message, '')), 'requested')
    returning id into new_id;
    return new_id;
exception when unique_violation then
    raise exception 'already_has_coach';
end $$;

-- Client withdraws a waiting request
create function public.cancel_coach_request() returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
begin
    delete from public.coachings where client_id = me.id and status = 'requested';
end $$;

-- Client has seen the decline; back to choosing a coach
create function public.dismiss_declined() returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
begin
    delete from public.coachings where client_id = me.id and status = 'declined';
end $$;

create function public.accept_invitation() returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
begin
    update public.coachings
    set status = 'active', since = public.coach_today(coach_id), client_id = me.id
    where email = me.email and status = 'invited';
    if not found then
        raise exception 'not_found';
    end if;
end $$;

create function public.decline_invitation() returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
begin
    delete from public.coachings where email = me.email and status = 'invited';
end $$;

-- Client stops working with their coach. The current program ends today.
create function public.leave_coach() returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
    c public.coachings;
begin
    select * into c from public.coachings
    where client_id = me.id and status in ('active', 'paused');
    if c.id is null then
        raise exception 'not_found';
    end if;
    update public.assignments
    set ended_on = least(public.coach_today(c.coach_id), start_date + weeks * 7 - 1),
        end_reason = 'ended'
    where coaching_id = c.id and ended_on is null and start_date <= public.coach_today(c.coach_id);
    delete from public.assignments
    where coaching_id = c.id and ended_on is null;
    update public.coachings set status = 'ended', ended_at = now() where id = c.id;
end $$;

-- Coach accepts or declines a request
create function public.respond_coach_request(p_coaching uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    update public.coachings
    set status = case when p_accept then 'active' else 'declined' end,
        since = case when p_accept then public.coach_today(me.id) else since end
    where id = p_coaching and coach_id = me.id and status = 'requested';
    if not found then
        raise exception 'not_found';
    end if;
end $$;

-- Coach invites a client by email; returns the coaching id
create function public.invite_client(p_name text, p_email text, p_goal text, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
    e text := lower(trim(p_email));
    existing_client uuid;
    new_id uuid;
begin
    select id into existing_client from public.profiles where email = e and role = 'client';
    insert into public.coachings (id, coach_id, client_id, email, name, goal, status, since)
    values (coalesce(p_id, gen_random_uuid()), me.id, existing_client, e, trim(p_name),
            trim(coalesce(p_goal, '')), 'invited', public.coach_today(me.id))
    returning id into new_id;
    return new_id;
exception when unique_violation then
    raise exception 'email_taken';
end $$;

-- Coach removes a client or withdraws an invitation
create function public.remove_client(p_coaching uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    delete from public.coachings
    where id = p_coaching and coach_id = me.id and status = 'invited';
    if found then
        return;
    end if;
    update public.coachings set status = 'ended', ended_at = now()
    where id = p_coaching and coach_id = me.id and status in ('active', 'paused');
    if not found then
        raise exception 'not_found';
    end if;
end $$;

-- Public or private profile. Going private declines the waiting requests.
create function public.set_visibility(p_visibility text) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    if p_visibility not in ('public', 'private') then
        raise exception 'not_allowed';
    end if;
    update public.coach_profiles set visibility = p_visibility where coach_id = me.id;
    if p_visibility = 'private' then
        update public.coachings set status = 'declined'
        where coach_id = me.id and status = 'requested';
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Functions: programs and assignments
-- ---------------------------------------------------------------------------

-- Saves a whole program from the editor:
-- { id, name, description, weeks,
--   days: [ { id, name, exercises: [ { id, exerciseId, sets, reps, load, rest, notes, weeks } ] } ] }
-- Days and entries are replaced. Week changes beyond the program length are dropped.
create function public.save_program(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
    pid uuid := coalesce(nullif(p ->> 'id', '')::uuid, gen_random_uuid());
    week_count int := greatest(1, least(52, coalesce((p ->> 'weeks')::int, 1)));
    owner uuid;
    d jsonb;
    x jsonb;
    day_pos int := 0;
    entry_pos int;
    day_id uuid;
begin
    if coalesce(trim(p ->> 'name'), '') = '' then
        raise exception 'invalid_program';
    end if;
    select coach_id into owner from public.programs where id = pid;
    if owner is not null and owner <> me.id then
        raise exception 'not_allowed';
    end if;

    insert into public.programs (id, coach_id, name, description, weeks, updated_at)
    values (pid, me.id, trim(p ->> 'name'), trim(coalesce(p ->> 'description', '')), week_count, now())
    on conflict (id) do update
        set name = excluded.name, description = excluded.description,
            weeks = excluded.weeks, updated_at = now();

    delete from public.program_days where program_id = pid;

    for d in select * from jsonb_array_elements(coalesce(p -> 'days', '[]'::jsonb)) loop
        day_id := coalesce(nullif(d ->> 'id', '')::uuid, gen_random_uuid());
        insert into public.program_days (id, program_id, position, name)
        values (day_id, pid, day_pos, coalesce(d ->> 'name', ''));
        day_pos := day_pos + 1;
        entry_pos := 0;
        for x in select * from jsonb_array_elements(coalesce(d -> 'exercises', '[]'::jsonb)) loop
            insert into public.program_entries
                (id, day_id, position, exercise_id, sets, reps, load, rest, notes, weeks)
            values (coalesce(nullif(x ->> 'id', '')::uuid, gen_random_uuid()), day_id, entry_pos,
                    (x ->> 'exerciseId')::uuid,
                    coalesce(x ->> 'sets', ''), coalesce(x ->> 'reps', ''), coalesce(x ->> 'load', ''),
                    coalesce(x ->> 'rest', ''), coalesce(x ->> 'notes', ''),
                    coalesce((select jsonb_object_agg(k, v)
                              from jsonb_each(coalesce(x -> 'weeks', '{}'::jsonb)) as w(k, v)
                              where k ~ '^[0-9]+$' and k::int between 1 and week_count), '{}'::jsonb));
            entry_pos := entry_pos + 1;
        end loop;
    end loop;
    return pid;
exception when foreign_key_violation then
    raise exception 'invalid_program';
end $$;

-- Gives a program to a client from p_start. The current program moves to the
-- history (or is dropped if it hasn't started yet).
create function public.assign_program(p_coaching uuid, p_program uuid, p_start date, p_note text,
                                      p_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
    c public.coachings;
    prog public.programs;
    cur public.assignments;
    today date := public.coach_today(me.id);
    new_id uuid;
begin
    select * into c from public.coachings
    where id = p_coaching and coach_id = me.id and status in ('active', 'paused');
    select * into prog from public.programs where id = p_program and coach_id = me.id;
    if c.id is null or prog.id is null then
        raise exception 'not_found';
    end if;

    select * into cur from public.assignments
    where coaching_id = c.id and ended_on is null
    order by created_at desc limit 1;
    if cur.id is not null then
        if today > cur.start_date + cur.weeks * 7 - 1 then
            update public.assignments
            set ended_on = cur.start_date + cur.weeks * 7 - 1, end_reason = 'completed'
            where id = cur.id;
        elsif today < cur.start_date then
            delete from public.assignments where id = cur.id;
        else
            update public.assignments set ended_on = today, end_reason = 'replaced' where id = cur.id;
        end if;
    end if;

    insert into public.assignments (id, coaching_id, program_id, program_name, weeks, start_date, note)
    values (coalesce(p_id, gen_random_uuid()), c.id, prog.id, prog.name, prog.weeks, p_start,
            trim(coalesce(p_note, '')))
    returning id into new_id;

    if c.status = 'paused' then
        update public.coachings set status = 'active' where id = c.id;
    end if;
    return new_id;
end $$;

create function public.extend_assignment(p_coaching uuid, p_weeks int) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    if p_weeks not between 1 and 52 then
        raise exception 'not_allowed';
    end if;
    update public.assignments a set weeks = a.weeks + p_weeks
    where a.id = (select a2.id from public.assignments a2
                  join public.coachings c on c.id = a2.coaching_id
                  where a2.coaching_id = p_coaching and c.coach_id = me.id and a2.ended_on is null
                  order by a2.created_at desc limit 1);
    if not found then
        raise exception 'not_found';
    end if;
end $$;

-- Ends the current program today (or removes it if it hasn't started)
create function public.end_program(p_coaching uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
    cur public.assignments;
    today date := public.coach_today(me.id);
begin
    select a.* into cur from public.assignments a
    join public.coachings c on c.id = a.coaching_id
    where a.coaching_id = p_coaching and c.coach_id = me.id and a.ended_on is null
    order by a.created_at desc limit 1;
    if cur.id is null then
        raise exception 'not_found';
    end if;
    if today < cur.start_date then
        delete from public.assignments where id = cur.id;
    elsif today > cur.start_date + cur.weeks * 7 - 1 then
        update public.assignments
        set ended_on = cur.start_date + cur.weeks * 7 - 1, end_reason = 'completed'
        where id = cur.id;
    else
        update public.assignments set ended_on = today, end_reason = 'ended' where id = cur.id;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Functions: calendar
-- ---------------------------------------------------------------------------

-- Replaces the coach's weekly hours: [ { weekday, start, end }, ... ]
create function public.save_working_hours(p_hours jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    delete from public.working_hours where coach_id = me.id;
    insert into public.working_hours (coach_id, weekday, start_min, end_min)
    select me.id, (h ->> 'weekday')::int, (h ->> 'start')::int, (h ->> 'end')::int
    from jsonb_array_elements(p_hours) as h;
    -- No overlapping ranges on the same day
    if exists (select 1 from public.working_hours a
               join public.working_hours b
                 on a.coach_id = b.coach_id and a.weekday = b.weekday and a.start_min < b.start_min
               where a.coach_id = me.id and b.start_min < a.end_min) then
        raise exception 'invalid_hours';
    end if;
exception when check_violation or unique_violation then
    raise exception 'invalid_hours';
end $$;

-- Times a coach is busy (confirmed or pending sessions, blocked slots) between
-- two instants, without saying who or why. For clients' booking calendars.
create function public.coach_busy(p_coach uuid, p_from timestamptz, p_to timestamptz)
returns table (starts_at timestamptz, ends_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
    if p_coach <> (select auth.uid()) and not public.is_linked(p_coach) and not public.is_public_coach(p_coach) then
        raise exception 'not_allowed';
    end if;
    return query
        select s.starts_at, s.ends_at from public.sessions s
        where s.coach_id = p_coach and s.status in ('confirmed', 'pending')
          and s.ends_at > p_from and s.starts_at < p_to
        union all
        select b.starts_at, b.starts_at + interval '30 minutes' from public.blocked_slots b
        where b.coach_id = p_coach and b.starts_at >= p_from - interval '30 minutes' and b.starts_at < p_to;
end $$;

-- Client asks for a session with their coach. It stays pending until the coach
-- confirms or declines it. Rules: 30 min to 3 h in 30-minute steps, starts on
-- a slot boundary at least 60 min from now, within the current week plus the
-- next three (coach's time zone), inside working hours, not blocked or taken.
create function public.request_session(p_coach uuid, p_starts timestamptz, p_ends timestamptz,
                                       p_type text, p_mode text, p_note text, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('client');
    tz text := public.coach_tz(p_coach);
    local_start timestamp := p_starts at time zone tz;
    local_end timestamp := p_ends at time zone tz;
    minutes int := (extract(epoch from (p_ends - p_starts)) / 60)::int;
    start_min int := (extract(hour from local_start) * 60 + extract(minute from local_start))::int;
    window_end timestamptz := (date_trunc('week', now() at time zone tz) + interval '28 days') at time zone tz;
    m int;
    new_id uuid;
begin
    if not exists (select 1 from public.coachings
                   where coach_id = p_coach and client_id = me.id and status = 'active') then
        raise exception 'not_allowed';
    end if;
    if minutes < 30 or minutes > 180 or minutes % 30 <> 0
       or start_min % 30 <> 0 or extract(second from local_start) <> 0
       or (local_end::date <> local_start::date and local_end <> (local_start::date + 1)::timestamp) then
        raise exception 'invalid_length';
    end if;
    if p_starts < now() + interval '60 minutes' then
        raise exception 'too_soon';
    end if;
    if p_starts >= window_end then
        raise exception 'too_far';
    end if;
    for m in select generate_series(start_min, start_min + minutes - 30, 30) loop
        if not exists (select 1 from public.working_hours w
                       where w.coach_id = p_coach
                         and w.weekday = extract(dow from local_start)::int
                         and m >= w.start_min and m + 30 <= w.end_min) then
            raise exception 'slot_unavailable';
        end if;
    end loop;
    if exists (select 1 from public.blocked_slots b
               where b.coach_id = p_coach and b.starts_at >= p_starts and b.starts_at < p_ends) then
        raise exception 'slot_unavailable';
    end if;

    insert into public.sessions (id, coach_id, client_id, client_name, client_email,
                                 starts_at, ends_at, type, mode, note, status, requested_at)
    values (coalesce(p_id, gen_random_uuid()), p_coach, me.id, me.name, me.email,
            p_starts, p_ends, coalesce(p_type, ''), coalesce(p_mode, ''), trim(coalesce(p_note, '')),
            'pending', now())
    returning id into new_id;
    return new_id;
exception when exclusion_violation then
    raise exception 'slot_unavailable';
end $$;

-- Coach confirms or declines a waiting booking
create function public.respond_session(p_session uuid, p_confirm boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me public.profiles := public.require_role('coach');
begin
    update public.sessions
    set status = case when p_confirm then 'confirmed' else 'declined' end
    where id = p_session and coach_id = me.id and status = 'pending' and ends_at > now();
    if not found then
        raise exception 'not_found';
    end if;
end $$;

-- Client: a confirmed or pending session, at least 24 h before it starts.
-- Coach: a confirmed session that hasn't started (pending ones are declined).
create function public.cancel_session(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
    s public.sessions;
    uid uuid := (select auth.uid());
begin
    select * into s from public.sessions where id = p_session;
    if s.id is null or (s.coach_id <> uid and s.client_id is distinct from uid) then
        raise exception 'not_found';
    end if;
    if s.client_id = uid then
        if s.status not in ('confirmed', 'pending') then
            raise exception 'not_allowed';
        end if;
        if s.starts_at - now() < interval '24 hours' then
            raise exception 'too_late_to_cancel';
        end if;
        update public.sessions set status = 'cancelled', cancelled_by = 'client' where id = s.id;
    else
        if s.status <> 'confirmed' or s.starts_at <= now() then
            raise exception 'not_allowed';
        end if;
        update public.sessions set status = 'cancelled', cancelled_by = 'coach' where id = s.id;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Function permissions: signed-in users only. Helpers aren't called directly.
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
grant execute on function
    public.request_coach(uuid, text, text),
    public.cancel_coach_request(),
    public.dismiss_declined(),
    public.accept_invitation(),
    public.decline_invitation(),
    public.leave_coach(),
    public.respond_coach_request(uuid, boolean),
    public.invite_client(text, text, text, uuid),
    public.remove_client(uuid),
    public.set_visibility(text),
    public.save_program(jsonb),
    public.assign_program(uuid, uuid, date, text, uuid),
    public.extend_assignment(uuid, int),
    public.end_program(uuid),
    public.save_working_hours(jsonb),
    public.coach_busy(uuid, timestamptz, timestamptz),
    public.request_session(uuid, timestamptz, timestamptz, text, text, text, uuid),
    public.respond_session(uuid, boolean),
    public.cancel_session(uuid),
    -- used inside RLS policies, so the querying role needs them
    public.is_linked(uuid),
    public.is_public_coach(uuid),
    public.can_read_program(uuid)
to authenticated;
