-- Tighter Realtime channel policy: besides joining only their own channel, a
-- user can read only that channel's messages (the first version checked just
-- the channel being joined, so it allowed reading other rows of
-- realtime.messages too; they carry only table names, and the realtime schema
-- isn't exposed through the API, but there's no reason to allow it).
alter policy "realtime: own user channel" on realtime.messages
    using (realtime.topic() = 'user:' || (select auth.uid())::text
           and topic = realtime.topic()
           and extension = 'broadcast');
