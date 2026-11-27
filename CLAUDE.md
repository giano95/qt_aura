# CLAUDE.md: working on Aura

Aura is a Qt 6.12 / QML coaching app with two roles (coach, client) in one app.
It runs on desktop first (**macOS and Windows**), with iOS and Android later
from the same QML. The backend is Supabase. `README.md` has the overview,
features, roadmap and architecture diagrams.

This file holds only what the code doesn't tell you: how to work here, what the
user decided, and the pitfalls already found.

## Finding your way around the code

- **graphify** keeps a knowledge graph of the C++ (`src/`), the SQL
  (`supabase/`) and the docs in `graphify-out/` (local, not in git):
  `graphify query "<question>"`, `graphify explain "<Node>"`,
  `graphify path "<A>" "<B>"`. After code changes, rebuild it with
  `/graphify . --update`.
  - It doesn't parse **QML**: for screens, search `qml/` directly.
  - It links calls by name, so same-named functions get mixed up (e.g. the
    three `toMs` helpers). Check in the code before acting on an edge.
  - It may be missing (the Mac has no graphify) or out of date. If so, read
    the code.
- The `README.md` Mermaid diagrams (architecture, and how a change reaches
  another device) are maintained by hand. Update them when you add a store, a
  backend class, or a connection between them.

## How to work here

- Git: `main` on `github.com/giano95/qt_aura`; GitHub is the source of truth.
  The user works on two machines and moves work between them by pushing:

| Machine | Clone | Qt | Tools |
|---|---|---|---|
| Windows PC | `C:\projects\qt_aura` | `C:\Qt\6.12.0\mingw_64` (MinGW 13.1) | `C:\Qt\Tools\{CMake_64,Ninja,mingw1310_64}` |
| Mac | `~/projects/qt_aura` | `~/Qt/6.12.0/macos` | `~/Qt/Tools/{CMake,Ninja}` |

- **The user edits files too, on either machine.** Before changing anything:
  1. run `git status` and `git fetch`; if `origin/main` is ahead, tell the
     user and pull first;
  2. never overwrite uncommitted changes you didn't make;
  3. never restore UI or code the user removed.
- Commit or push only when the user asks. Never commit `build/`,
  `.qtcreator/` or `CMakeLists.txt.user` (they differ per machine).
- **It must build and run on macOS and Windows.** No platform-specific code,
  paths or fonts without a fallback for the other one.
- Build and lint in a temp folder (the scratchpad, or `/tmp` on the Mac), not
  in `build/` (that belongs to Qt Creator). Both must be clean before you're
  done. If you can only check one machine, say so.

```bash
# Windows (Git Bash)
export PATH=/c/Qt/Tools/CMake_64/bin:/c/Qt/Tools/Ninja:/c/Qt/Tools/mingw1310_64/bin:$PATH
cmake -S C:/projects/qt_aura -B <tmp>/qt_aura_check -G Ninja -DCMAKE_PREFIX_PATH=C:/Qt/6.12.0/mingw_64
# macOS
export PATH=$HOME/Qt/Tools/CMake/CMake.app/Contents/bin:$HOME/Qt/Tools/Ninja:$PATH
cmake -S ~/projects/qt_aura -B /tmp/qt_aura_check -G Ninja -DCMAKE_PREFIX_PATH=$HOME/Qt/6.12.0/macos
# both
cmake --build <dir> && cmake --build <dir> --target all_qmllint   # no "Warning:" lines
```

  To run the `.exe` outside Qt Creator, put `C:/Qt/6.12.0/mingw_64/bin` and
  `C:/Qt/Tools/mingw1310_64/bin` on `PATH`. Each machine needs the Qt
  WebSockets add-on and, on the first configure, internet (CMake downloads
  QtKeychain).
- **Every new QML file goes in `QML_FILES`** in `CMakeLists.txt` (singletons
  also in `AURA_QML_SINGLETONS`, with `pragma Singleton`). Check:
  `for f in $(find qml -name '*.qml'); do grep -q "$f" CMakeLists.txt || echo "$f"; done`
- **Every new C++ file goes in `SOURCES`** of `qt_add_qml_module`, and its
  folder in `target_include_directories`. Headers are `.hpp`.
- The Windows PC has Python (`py`, 3.15; graphify runs on 3.14 through pipx)
  and Perl (from Git for Windows). Long heredocs with quotes can break the
  Bash tool, so write scripts to files instead.

### Checking changes at runtime

There's no test suite yet (unit tests are the last item of Phase 2). Use a
throwaway **screenshot driver**, and never put it in the project:
1. copy the project to a temp folder, without `build/` and `.qtcreator/`;
2. replace `main.cpp` with a driver that creates the `SupabaseClient` and the
   `RealtimeClient` before the engine (like the real `main.cpp`), loads module
   `qt_aura`, runs timed steps and saves `grabWindow()` PNGs;
3. run it with `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software` and a
   timeout: `timeout 90 ./appqt_aura.exe` on Windows, or
   `perl -e "alarm 90; exec @ARGV" ./appqt_aura.app/Contents/MacOS/appqt_aura`
   on the Mac (it has no `timeout`).

Pitfalls:
- Call `W->update()` on a ~16 ms timer, or animations freeze and grabs go stale.
- Resize in steps (900 px, then 390 px) before phone-size shots. Popups closed
  in the same step can still show in the next grab.
- When searching the object tree, keep a visited set (`children()` and
  `childItems()` overlap).
- Windows: set `QT_FORCE_STDERR_LOGGING=1` to see logs, and
  `QT_QPA_FONTDIR=C:/Windows/Fonts` or text shows as boxes. Keep the build
  path short (CMake warns above 250-char object paths).
- Run QML with `QQmlExpression(qmlContext(window), window, code)`; that
  context sees the singletons and `Main.qml` ids, and the root context
  doesn't. JS globals don't persist between expressions.
- Set `AURA_NO_SAVED_LOGIN=1` when the driver logs in by itself, or a saved
  login is restored at startup and races it.
- Switch themes with `AppSettings.themeMode = 'dark'` (`Theme.dark` is
  read-only). It's saved, so give the driver its own
  `setOrganizationName(...)`, or it changes the real app's choice.
- Test live updates with two drivers at once (`PHASE=coach &` and
  `PHASE=client &`, then `wait`).
- It uses the real Supabase project: delete the accounts it creates
  (`delete from auth.users where email like 'signup-test-%'`).

## Backend (Supabase)

- Project `dpijfmdalkhbgfxkrwws` (EU), through the `supabase` MCP server
  (`/mcp` to log in).
- **Schema changes:** add a new file in `supabase/migrations/`, then apply it
  with MCP `apply_migration` under the file's name minus the timestamp. Never
  change it only in the dashboard. Migrations 1–13 and `seed.sql` are applied.
- Test rules by impersonating a user in a rolled-back transaction:
  `set_config('request.jwt.claims', '{"sub": "<profile id>", "role": "authenticated"}', true)`,
  `set local role authenticated`, call the functions, end with
  `raise exception` to print and roll back.
- App-facing functions are `security definer` and executable by
  `authenticated` on purpose (the advisor warns about each one). Internal
  helpers must not be executable by API users.
- **A new table the app shows needs a live-update trigger:** add a branch in
  `realtime_on_change()` (new migration), and add the table to `start({...})`
  of the stores that show it.
- Seed accounts all use password `password`. Giulia Rossi (`coach@aura.app`)
  is the coach with clients, programs and a calendar. The sample coaches have
  no clients and nothing answers automatically.

## Pitfalls in the C++ ↔ QML bridge

- **Bindings that call a store function must pass the store's `revision`
  last** (`ProgramStore.searchExercises(text, muscle, ProgramStore.revision)`).
  Otherwise they don't re-run when store data changes. Reading list
  properties directly is fine.
- **Editor drafts must be real JS objects:** a `QJSValue` from a
  `QJsonObject`. A `QVariantMap` gives list wrappers that copy on read, and
  in-place edits get lost.
- Store writes go through `write()` / `writeRpc()`, a queue that sends one
  request at a time, because parallel requests arrived out of order. Reload
  with `requestLoad()`, not `load()`, so the reload waits for the queue.
- Ids are UUID strings; `""` means new or none.
- AUTOMOC only notices `Q_OBJECT` / `Q_GADGET` at the start of a line.
- Only one running copy stays logged in: Supabase revokes a login whose
  rotated token is used twice.

## QML conventions and pitfalls

- **Stores own all data and rules; screens only call them.**
- Import `QtQuick.Controls.Basic`. Never hard-code colors or sizes; use
  `Theme.*` (`Theme.toneColor` / `toneSoftColor` for `primary`, `accent`,
  `danger`, `neutral`).
- Start every file with a comment saying what it is. Put `qsTr()` around
  all visible text.
- Use `pragma ComponentBehavior: Bound` in files with delegates. Delegates
  declare `required property` and reference each other by id, never
  `parent.parent`.
- **Prefix generic components with `Aura`.** Qt 6.10's `SearchField`
  silently replaced ours.
- Never name a property `on` + a capital letter (it's parsed as a handler).
  Don't declare `accepted` / `rejected` signals on a `Dialog`. Don't use
  `state` as a custom name.
- Fixed-width fields in a `GridLayout` or `RowLayout` need
  `Layout.fillWidth: false`.
- In-place editors (`ProgramEditor`, `WorkingHoursEditor`) change the draft in
  place and bump a `revision` int passed to bindings. Rebuilding the draft on
  every keystroke loses focus. Structural edits replace the draft.
- Repeaters over JS arrays give delegates a copy in `modelData`: write
  through the store or editor by index.
- A `Toast` must be a child of a plain `Item` root, not inside a `ScrollView`.
- Singletons can be read before their bindings update (e.g. right after
  login), so react to changes, not only in `Component.onCompleted`.
- Open menus with `popup(item, x, y)`, not `popup()`.
- **Tabs are addressed by index** (`navigateRequested(index)`). If you
  reorder them in `CoachHome` / `ClientHome`, update the index constants in
  pages (`calendarTab`, `coachTab`, `messagesTab`, `programTab`, …).

## User decisions (don't undo)

- Nobody accepts or confirms automatically: coaching requests and bookings
  wait for the coach to answer from their own account. Every booking is
  `pending` until then.
- Public coaches are listed and receive requests. Private coaches aren't
  listed and invite by email. Switching to private declines waiting requests.
- Menu badges: **Clients** is green for requests and red for expired
  programs; **Calendar** is green for booking requests; **Messages** is green
  for unread messages. Requests are green, problems red.
- **Messages work like WhatsApp:** one conversation per coaching; coach and
  client write any time while it's active or paused. When it ends, both keep
  the history read-only (a new coaching is a new conversation). No editing or
  deleting sent messages (v1). WhatsApp ticks on own messages, for both
  sides (in the bubble and before "You: …" in the list): clock = sending,
  one tick = on the server, two = the other app received it (recorded when
  it loads its conversations, so only while it's open until push exists),
  blue (`Theme.receiptRead*`) = read. No "Seen" label, no switch to turn
  read receipts off. Coach: two
  panes, past clients in a collapsed section. Client: same layout, with past
  coaches. Desktop: Enter sends, Shift+Enter new line. A pop-up (MessageToast)
  shows a new message unless its chat is on screen.
- The chat has a WhatsApp-style background: fitness doodles repeated
  behind the messages (`MessageThread`, `Theme.chatPatternOpacity`). The
  user supplied the artwork (`tools/chat_pattern/source.jpeg`, it doesn't
  repeat by itself); `tools/chat_pattern.py` cuts out the doodles and
  scatters them on a seamless tile in `assets/chat/` (needs numpy and scipy).
- Messages are text only for now, built so images and voice can be added:
  `messages.kind`, a future `message_attachments` table, files in Supabase
  Storage (private bucket per coaching, signed URLs), uploads outside the
  write queue.
- **No banners on the coach's Clients page** (the user removed them). Leave
  the unused `expiredCount` property in `ClientsHome` unless asked.
- **Exercises** is its own sidebar entry, not a tab in Programs.
- Working hours are edited in a dialog opened from the Calendar header.
- Client tab names: **"My program"** and **"Calendar"**.
- In the coach's calendar, clicking a session opens its details (no menu).
- Default window 1920×1080, shrunk to fit smaller screens.
- **Settings** is one page for both apps, opened from the bottom of the
  sidebar (desktop) or the top bar (phone); it isn't a tab and covers the
  current page until a tab is picked. For now only appearance: System /
  Light / Dark, saved on the device (`AppSettings`, QSettings), not per
  account. The login screen keeps its own light/dark button.
- All stores are C++ (the user wants C++ and unit tests).
- Exercise images come from **Open Exercise Art** (CC BY-SA 4.0), line
  drawings only: no muscle highlight. Dark lines in the light theme, light
  lines in the dark one (`ExerciseImage`). Only the DB's exercises ship in
  `assets/exercises/`; the full set is in `third_party/open-exercise-art/`.
  To add one: `tools/exercise_images.py <id>`, then set `exercises.image`
  in a migration. Every built-in exercise has a drawing.
- The drawings must be credited wherever they are shown or shared (see the
  README's Credits).

## Known gaps

- The app doesn't credit Open Exercise Art on any screen yet (CC BY-SA needs
  it before release). Coaches can't pick a drawing for their own exercises.

- Not designed: **Progress** (client). The client **Home** still uses
  `MockData` (except the coach's latest message). The coach dashboard's
  "Unread messages" stat is still sample data.
- Messages: no push notifications (Phase 6), no images or voice yet, no
  search. Message text can't be selected or copied.
- Clients get no notification or badge when the coach confirms, declines or
  cancels a booking, or accepts a request.
- On phones the booking "Request" bar sits below the grid.
- The **⋯** badge on confirmed sessions is left over from the old menu.
- Coaches can't edit their public profile (bio, price, …) in the app.
- Dates are the device's local days; the server uses the coach's time zone.
  They differ only outside Europe/Rome.
- Live updates reload the whole store on each notice (except MessageStore,
  which fetches only new messages). The directory of
  public coaches isn't live. The coach's calendar loads all sessions at once
  (it needs paging by week).
- Booking limits are written in both `CalendarStore` and the SQL functions,
  and must be changed in both.
- The muscle tree is written in both `Exercise::muscleTree()` and the
  `exercises_parts_per_muscle` check (every group needs one of its parts,
  Cardio has none), and must be changed in both.

## Open product questions (ask, don't guess)

- One-off extra hours, or multi-day time off for coaches?
- Notification badges for clients on Calendar / My coach?
- Session length per type, or always free?
- Supersets / circuits in programs?
- Reviews or ratings in the directory (they need moderation)?
