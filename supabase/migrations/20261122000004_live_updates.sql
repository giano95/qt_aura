-- Live updates: when data changes, tell each affected user which table
-- changed, on their private Realtime channel "user:<profile id>". The message
-- carries no data ({ "table": "sessions" }); the app re-reads the table through
-- the normal API, so RLS still decides what each user sees.
--
-- One message per user and table per transaction, however many rows changed.
-- realtime.send() never raises (it turns errors into warnings), so a
-- notification problem can't block a change.

-- Sends "changed" for p_table to each user, once per transaction
create function public.realtime_notify(p_users uuid[], p_table text) returns void
language plpgsql security definer set search_path = '' as $$
declare
    sent text := coalesce(current_setting('aura.realtime_sent', true), '');
    u uuid;
    key text;
begin
    for u in select distinct x from unnest(p_users) as x where x is not null loop
        key := p_table || ':' || u::text;
        continue when position(key in sent) > 0;
        perform realtime.send(jsonb_build_object('table', p_table), 'changed', 'user:' || u::text, true);
        sent := sent || ' ' || key;
    end loop;
    perform set_config('aura.realtime_sent', sent, true);
end $$;

-- A coach and their current clients (whose calendars show the coach's free time)
create function public.coach_and_clients(p_coach uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
    select array_append(coalesce(array_agg(c.client_id), '{}'), p_coach)
    from public.coachings c
    where c.coach_id = p_coach and c.client_id is not null and c.status in ('active', 'paused')
$$;

-- Row trigger for every table below: works out who is affected
create function public.realtime_on_change() returns trigger
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
    when 'assignments' then
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

create trigger realtime_notify after insert or update or delete on public.coachings
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.assignments
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.sessions
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.blocked_slots
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.working_hours
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.exercises
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.coach_profiles
    for each row execute function public.realtime_on_change();
create trigger realtime_notify after insert or update or delete on public.programs
    for each row execute function public.realtime_on_change();

-- Internal helpers: not callable through the API
revoke execute on function public.realtime_notify(uuid[], text) from public, anon, authenticated;
revoke execute on function public.coach_and_clients(uuid) from public, anon, authenticated;
revoke execute on function public.realtime_on_change() from public, anon, authenticated;

-- Each signed-in user can join only their own channel
create policy "realtime: own user channel" on realtime.messages
    for select to authenticated
    using (realtime.topic() = 'user:' || (select auth.uid())::text and extension = 'broadcast');
