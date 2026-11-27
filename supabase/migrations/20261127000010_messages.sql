-- Messages between a coach and a client: one conversation per coaching.
-- Both can write any time while the coaching is active or paused. Once it has
-- ended the conversation stays readable by both, but nobody can write in it.
-- Text only for now: `kind` is there so images and voice messages can be added
-- later (with a message_attachments table) without changing what exists.
--
-- New error code: conversation_closed (the coaching isn't active or paused).

create table public.messages (
    id           uuid primary key default gen_random_uuid(),
    coaching_id  uuid not null references public.coachings (id) on delete cascade,
    sender_id    uuid not null references public.profiles (id) on delete cascade,
    kind         text not null default 'text' check (kind in ('text')),
    body         text not null check (char_length(body) <= 4000),
    created_at   timestamptz not null default now()
);
create index messages_coaching_time_idx on public.messages (coaching_id, created_at desc);
create index messages_sender_idx on public.messages (sender_id);

-- How far each person has read a conversation (unread counts, "Seen")
create table public.message_reads (
    coaching_id   uuid not null references public.coachings (id) on delete cascade,
    profile_id    uuid not null references public.profiles (id) on delete cascade,
    last_read_at  timestamptz not null,
    primary key (coaching_id, profile_id)
);
create index message_reads_profile_idx on public.message_reads (profile_id);

-- ---------------------------------------------------------------------------
-- Who can read: the coaching's coach and client (any status). Nobody writes
-- directly; the functions below do.
-- ---------------------------------------------------------------------------

-- The signed-in user is the coach or the client of the coaching
create function public.in_coaching(p_coaching uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.coachings c
                   where c.id = p_coaching
                     and (c.coach_id = (select auth.uid()) or c.client_id = (select auth.uid())))
$$;

alter table public.messages      enable row level security;
alter table public.message_reads enable row level security;

create policy "messages: either side" on public.messages
    for select to authenticated
    using (public.in_coaching(coaching_id));
create policy "message_reads: either side" on public.message_reads
    for select to authenticated
    using (public.in_coaching(coaching_id));

-- ---------------------------------------------------------------------------
-- Functions the app calls
-- ---------------------------------------------------------------------------

-- Sends a message; p_id lets the app create the id, so sending the same
-- message again (after a lost reply) doesn't make a copy. Sending also marks
-- the conversation read for the sender. Returns the message.
create function public.send_message(p_coaching uuid, p_body text, p_id uuid default null)
returns public.messages language plpgsql security definer set search_path = '' as $$
declare
    me uuid := (select auth.uid());
    c public.coachings;
    b text := btrim(coalesce(p_body, ''), E' \t\r\n');
    new_id uuid := coalesce(p_id, gen_random_uuid());
    m public.messages;
begin
    if me is null then
        raise exception 'not_signed_in';
    end if;
    select * into c from public.coachings
    where id = p_coaching and (coach_id = me or client_id = me);
    if c.id is null then
        raise exception 'not_found';
    end if;
    if c.status not in ('active', 'paused') then
        raise exception 'conversation_closed';
    end if;
    if char_length(b) = 0 or char_length(b) > 4000 then
        raise exception 'invalid_length';
    end if;

    insert into public.messages (id, coaching_id, sender_id, body)
    values (new_id, c.id, me, b)
    on conflict (id) do nothing;
    select * into m from public.messages
    where id = new_id and sender_id = me and coaching_id = c.id;
    if m.id is null then
        -- p_id was taken by someone else's message
        raise exception 'not_allowed';
    end if;

    insert into public.message_reads (coaching_id, profile_id, last_read_at)
    values (c.id, me, m.created_at)
    on conflict (coaching_id, profile_id)
    do update set last_read_at = greatest(public.message_reads.last_read_at, excluded.last_read_at);
    return m;
end $$;

-- Marks the conversation read up to p_until (the newest message the user has
-- seen, so a message that arrived meanwhile stays unread)
create function public.mark_read(p_coaching uuid, p_until timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me uuid := (select auth.uid());
begin
    if me is null then
        raise exception 'not_signed_in';
    end if;
    if not public.in_coaching(p_coaching) then
        raise exception 'not_found';
    end if;
    insert into public.message_reads (coaching_id, profile_id, last_read_at)
    values (p_coaching, me, least(p_until, now()))
    on conflict (coaching_id, profile_id)
    do update set last_read_at = greatest(public.message_reads.last_read_at, excluded.last_read_at)
    where public.message_reads.last_read_at < excluded.last_read_at;
end $$;

-- The signed-in user's conversations: every active or paused coaching, and
-- ended ones that have messages. One row each, with the other person, the
-- last message, the last message from the other person, the unread count and
-- how far each side has read.
create function public.conversations()
returns table (
    coaching_id uuid, status text, ended_at timestamptz,
    other_id uuid, other_name text,
    last_id uuid, last_sender uuid, last_body text, last_at timestamptz,
    other_last_body text, other_last_at timestamptz,
    unread int, my_read_at timestamptz, other_read_at timestamptz)
language sql stable security definer set search_path = '' as $$
    with me as (select (select auth.uid()) as id)
    select c.id, c.status, c.ended_at,
           o.id, coalesce(o.name, c.name),
           l.id, l.sender_id, l.body, l.created_at,
           ol.body, ol.created_at,
           (select count(*)::int from public.messages m
            where m.coaching_id = c.id and m.sender_id <> me.id
              and m.created_at > coalesce(mr.last_read_at, '-infinity')),
           mr.last_read_at, orr.last_read_at
    from me
    join public.coachings c on c.coach_id = me.id or c.client_id = me.id
    left join public.profiles o
           on o.id = case when c.coach_id = me.id then c.client_id else c.coach_id end
    left join lateral (select m.id, m.sender_id, m.body, m.created_at from public.messages m
                       where m.coaching_id = c.id order by m.created_at desc limit 1) l on true
    left join lateral (select m.body, m.created_at from public.messages m
                       where m.coaching_id = c.id and m.sender_id <> me.id
                       order by m.created_at desc limit 1) ol on true
    left join public.message_reads mr on mr.coaching_id = c.id and mr.profile_id = me.id
    left join public.message_reads orr on orr.coaching_id = c.id and orr.profile_id = o.id
    where c.client_id is not null
      and (c.status in ('active', 'paused') or (c.status = 'ended' and l.id is not null))
$$;

-- ---------------------------------------------------------------------------
-- Live updates: both sides hear about new messages and reads
-- ---------------------------------------------------------------------------

create or replace function public.realtime_on_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
    r record;
    users uuid[];
begin
    if tg_op = 'DELETE' then
        r := old;
    else
        r := new;
    end if;
    case tg_table_name
    when 'coachings' then
        users := array[r.coach_id, r.client_id];
    when 'assignments', 'messages', 'message_reads' then
        select array[c.coach_id, c.client_id] into users
        from public.coachings c where c.id = r.coaching_id;
    when 'sessions' then
        -- the coach's clients see the coach's free time change
        users := public.coach_and_clients(r.coach_id) || r.client_id;
    when 'blocked_slots', 'working_hours', 'exercises', 'coach_profiles' then
        users := public.coach_and_clients(r.coach_id);
    when 'programs' then
        select array_append(coalesce(array_agg(c.client_id), '{}'), r.coach_id) into users
        from public.assignments a
        join public.coachings c on c.id = a.coaching_id
        where a.program_id = r.id and c.status in ('active', 'paused');
    end case;
    perform public.realtime_notify(users, tg_table_name);
    return null;
end $$;

create trigger realtime_notify after insert or update or delete on public.messages
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.message_reads
    for each row execute function public.realtime_on_change();

-- in_coaching stays executable: RLS policies call it as the querying user,
-- and it only says whether they belong to a coaching they can already read.
revoke execute on function public.realtime_on_change() from public, anon, authenticated;
