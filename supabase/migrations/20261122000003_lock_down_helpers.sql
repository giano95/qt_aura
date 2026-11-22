-- Internal helpers are only called from inside security definer functions
-- (which run as the owner), so signed-in users don't need to call them through
-- the API. is_linked / is_public_coach / can_read_program stay executable:
-- RLS policies call them as the querying user, and they only reveal what that
-- user can already read.
revoke execute on function
    public.require_role(text),
    public.coach_tz(uuid),
    public.coach_today(uuid),
    public.handle_new_user()
from public, anon, authenticated;

-- Covering index for the exercises -> profiles foreign key (performance advisor)
create index exercises_coach_idx on public.exercises (coach_id);
