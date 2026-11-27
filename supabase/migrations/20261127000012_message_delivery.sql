-- Delivery ticks, like WhatsApp: on the sender's messages
--   one tick   = the server has it
--   two ticks  = the other person's app has received it
--   blue ticks = the other person has read it
-- Each side keeps two positions per conversation in message_reads: how far
-- their app has received (last_delivered_at) and how far they have read
-- (last_read_at). A message's ticks come from comparing its time with the
-- other person's positions; nothing is stored per message.
--
-- The app records delivery when it loads its conversations (it then has the
-- other person's newest message), and reading when the chat is on screen.
-- Reading also counts as received.

alter table public.message_reads
    add column last_delivered_at timestamptz,
    alter column last_read_at drop not null;

update public.message_reads set last_delivered_at = last_read_at;

-- Marks the conversation read up to p_until (and received)
create or replace function public.mark_read(p_coaching uuid, p_until timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me uuid := (select auth.uid());
    t timestamptz := least(p_until, now());
begin
    if me is null then
        raise exception 'not_signed_in';
    end if;
    if not public.in_coaching(p_coaching) then
        raise exception 'not_found';
    end if;
    insert into public.message_reads (coaching_id, profile_id, last_read_at, last_delivered_at)
    values (p_coaching, me, t, t)
    on conflict (coaching_id, profile_id)
    do update set last_read_at = greatest(public.message_reads.last_read_at, excluded.last_read_at),
                  last_delivered_at = greatest(public.message_reads.last_delivered_at, excluded.last_read_at)
    where coalesce(public.message_reads.last_read_at, '-infinity') < excluded.last_read_at
       or coalesce(public.message_reads.last_delivered_at, '-infinity') < excluded.last_read_at;
end $$;

-- Marks the conversation received up to p_until (the newest message from the
-- other person that the app has). Only moves forward, so calling it again
-- writes nothing and sends no live update.
create function public.mark_delivered(p_coaching uuid, p_until timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
    me uuid := (select auth.uid());
    t timestamptz := least(p_until, now());
begin
    if me is null then
        raise exception 'not_signed_in';
    end if;
    if not public.in_coaching(p_coaching) then
        raise exception 'not_found';
    end if;
    insert into public.message_reads (coaching_id, profile_id, last_delivered_at)
    values (p_coaching, me, t)
    on conflict (coaching_id, profile_id)
    do update set last_delivered_at = excluded.last_delivered_at
    where coalesce(public.message_reads.last_delivered_at, '-infinity') < excluded.last_delivered_at;
end $$;

-- Sending marks the conversation read and received for the sender
create or replace function public.send_message(p_coaching uuid, p_body text, p_id uuid default null)
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

    insert into public.message_reads (coaching_id, profile_id, last_read_at, last_delivered_at)
    values (c.id, me, m.created_at, m.created_at)
    on conflict (coaching_id, profile_id)
    do update set last_read_at = greatest(public.message_reads.last_read_at, excluded.last_read_at),
                  last_delivered_at = greatest(public.message_reads.last_delivered_at, excluded.last_delivered_at);
    return m;
end $$;

-- conversations() also returns how far each side has received. The returned
-- columns change, so the function is dropped and created again.
drop function public.conversations();

create function public.conversations()
returns table (
    coaching_id uuid, status text, ended_at timestamptz,
    other_id uuid, other_name text,
    last_id uuid, last_sender uuid, last_body text, last_at timestamptz,
    other_last_body text, other_last_at timestamptz,
    unread int, my_read_at timestamptz, other_read_at timestamptz,
    my_delivered_at timestamptz, other_delivered_at timestamptz)
language sql stable security definer set search_path = '' as $$
    with me as (select (select auth.uid()) as id)
    select c.id, c.status, c.ended_at,
           o.id, coalesce(o.name, c.name),
           l.id, l.sender_id, l.body, l.created_at,
           ol.body, ol.created_at,
           (select count(*)::int from public.messages m
            where m.coaching_id = c.id and m.sender_id <> me.id
              and m.created_at > coalesce(mr.last_read_at, '-infinity')),
           mr.last_read_at, orr.last_read_at,
           greatest(mr.last_delivered_at, mr.last_read_at),
           greatest(orr.last_delivered_at, orr.last_read_at)
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

revoke execute on function
    public.mark_delivered(uuid, timestamptz),
    public.conversations()
from public, anon;

grant execute on function
    public.mark_delivered(uuid, timestamptz),
    public.conversations()
to authenticated;
