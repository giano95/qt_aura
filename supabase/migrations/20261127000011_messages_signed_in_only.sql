-- Messages are for signed-in users only, like everything else (the schema's
-- blanket revokes ran before these tables and functions existed).

revoke all on public.messages, public.message_reads from anon;

revoke execute on function
    public.in_coaching(uuid),
    public.send_message(uuid, text, uuid),
    public.mark_read(uuid, timestamptz),
    public.conversations()
from public, anon;

grant execute on function
    public.in_coaching(uuid),
    public.send_message(uuid, text, uuid),
    public.mark_read(uuid, timestamptz),
    public.conversations()
to authenticated;
