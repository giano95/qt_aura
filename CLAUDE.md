# CLAUDE.md: context for working on Aura

Read this before changing anything. `README.md` has the user-facing overview
(features, how to run, roadmap); this file holds what you need to work on the
code safely.

## The project in brief

- **Aura**: a Qt 6 / QML coaching app with two roles, **coach** and **client**, in one
  app. Desktop first, on **macOS and Windows**; iOS and Android later with the same QML.
- **Phase 0** (interactive prototype) is essentially done.
- **Phase 1** (Supabase backend) is **done**: schema, row-level security, rules and
  demo data are live (see "Backend").
- **Phase 2 in progress**: a C++ `SupabaseClient`, with each store replaced by a
  C++ class exposing the same API. All five stores are C++ now (`src/stores/`);
  only `MockData` (sample dashboard content) is left in `qml/services/`.
- Qt **6.12.0** on both of the developer's machines (see below).
  `qt_standard_project_setup(REQUIRES 6.10)`.
- **The project must build and run on both macOS and Windows.** Don't add
  platform-specific code, paths or fonts without a fallback for the other one.

## Where the code lives and how to work on it

- **Git repository, `main` branch, remote `origin` = `github.com/giano95/qt_aura`.**
  GitHub is the source of truth. The user works on two machines, each with its own
  clone, and moves work between them by committing and pushing:

| Machine | Clone | Qt | Tools |
|---|---|---|---|
| Windows PC | `C:\projects\qt_aura` | `C:\Qt\6.12.0\mingw_64` (MinGW 13.1) | `C:\Qt\Tools\{CMake_64,Ninja,mingw1310_64}` |
| Mac | `~/projects/qt_aura` | `~/Qt/6.12.0/macos` | `~/Qt/Tools/{CMake,Ninja}` |

- **The user also edits files themselves, on either machine.** Before changing anything:
  1. `git status` and `git fetch`; if `origin/main` is ahead, tell the user and
     pull before editing (their latest work may be on the other machine);
  2. never overwrite uncommitted changes you didn't make;
  3. never restore UI or code the user removed (see "User decisions").
- Commit or push only when the user asks.
- `.gitignore` excludes `build/` and `.qtcreator/` (Qt Creator's per-machine files).
  `CMakeLists.txt.user` and kit names differ per machine; never commit them.
- Build and lint (both must be clean before you're done). Build in a temp folder
  (the scratchpad, or `/tmp` on the Mac), not in the project's `build/` folder
  (that belongs to Qt Creator).

  **Windows** (Bash tool, Git Bash):

```bash
export PATH=/c/Qt/Tools/CMake_64/bin:/c/Qt/Tools/Ninja:/c/Qt/Tools/mingw1310_64/bin:$PATH
cmake -S C:/projects/qt_aura -B <tmp>/qt_aura_check -G Ninja \
      -DCMAKE_PREFIX_PATH=C:/Qt/6.12.0/mingw_64
cmake --build <tmp>/qt_aura_check
cmake --build <tmp>/qt_aura_check --target all_qmllint   # expect no "Warning:" lines
```

  To run the `.exe` outside Qt Creator, put `C:/Qt/6.12.0/mingw_64/bin` and
  `C:/Qt/Tools/mingw1310_64/bin` on `PATH` (the Qt and MinGW DLLs live there).

  **macOS:**

```bash
export PATH=$HOME/Qt/Tools/CMake/CMake.app/Contents/bin:$HOME/Qt/Tools/Ninja:$PATH
cmake -S ~/projects/qt_aura -B /tmp/qt_aura_check -G Ninja \
      -DCMAKE_PREFIX_PATH=$HOME/Qt/6.12.0/macos
cmake --build /tmp/qt_aura_check
cmake --build /tmp/qt_aura_check --target all_qmllint   # expect no "Warning:" lines
```

  If you can only build on one machine, say so: the other one hasn't been checked.
- **Every new QML file must be added to `QML_FILES` in `CMakeLists.txt`.**
  Singletons also go in `AURA_QML_SINGLETONS`, which sets `QT_QML_SINGLETON_TYPE`,
  and need `pragma Singleton`. Quick check that nothing is missing:
  `for f in $(find qml -name '*.qml'); do grep -q "$f" CMakeLists.txt || echo "$f"; done`

### Checking changes at runtime (what has worked)

There is no test suite. Behaviour has been checked with a throwaway **screenshot
driver**:
1. copy the project to a temp folder (e.g. `/tmp/aura_shots/src` on the Mac, the
   scratchpad on Windows), excluding `build/` and `.qtcreator/`;
2. replace `main.cpp` with a C++ driver that loads the `qt_aura` module, runs timed
   steps (log in through `Session`, set `router.item.currentIndex`, call store or
   page functions, send real `QMouseEvent`s to `QQuickWindow`), and saves
   `grabWindow()` PNGs;
3. run it with `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software` and a timeout:
   - macOS: `perl -e "alarm 90; exec @ARGV" ./build/appqt_aura.app/Contents/MacOS/appqt_aura`
   - Windows (Git Bash, Qt and MinGW `bin` on `PATH`): `timeout 90 ./build/appqt_aura.exe`

Pitfalls with the offscreen platform:
- Call `W->update()` on a ~16 ms timer, or animations and transitions freeze and
  screenshots go stale.
- Resize in steps (e.g. 900 px, then 390 px) before taking phone-size shots.
- Popups closed in the same step can still show in the next grab.
- When searching the object tree, keep a visited set: `children()` and
  `childItems()` overlap, and without it the search blows up.
- macOS has no `timeout` command; use `perl -e "alarm N"` there. Git Bash on
  Windows has `timeout`.
- Windows: the app is a GUI-subsystem exe, so set `QT_FORCE_STDERR_LOGGING=1`
  to see `qInfo`/warnings, and `QT_QPA_FONTDIR=C:/Windows/Fonts` or offscreen
  screenshots show boxes instead of text. Keep the driver's build path short-ish
  (CMake warns above 250-char object paths).
- The driver talks to the real Supabase project now: delete any accounts it
  creates (e.g. sign up `signup-test-…@example.com`, then
  `delete from auth.users where email like 'signup-test-%'`).
- The driver's `main.cpp` must create the `SupabaseClient` (and the
  `RealtimeClient`, for live updates) before the engine, like the real `main.cpp`.
- Run drivers that log in by themselves with `AURA_NO_SAVED_LOGIN=1`, or a
  saved login from an earlier run is restored at startup and races the
  driver's own login. (The driver doesn't set an application name, so its
  saved login is separate from the real app's anyway.)
- Live updates can be tested with two drivers at once (e.g. `PHASE=coach` and
  `PHASE=client` started with `&` in one Bash call, then `wait`): one changes
  data, the other logs what it sees every few seconds.
- To run QML from the driver, use `QQmlExpression(qmlContext(window), window, code)`:
  that context sees the module's singletons and `Main.qml` ids (`router`); the
  engine's root context doesn't. JS globals don't persist between expressions.
- The Windows PC has no Python (the `python` command opens the Store); Perl
  comes with Git for Windows. Long heredocs with quotes can break the Bash
  tool; write scripts to files instead.
- Never put this driver into the project.

## Backend (Phase 1 done, Phase 2 next)

Supabase project `dpijfmdalkhbgfxkrwws` (EU), reachable through the `supabase`
MCP server in `.mcp.json` (log in with `/mcp`). Decisions taken with the user
(2026-11-22):

- **Database** (`supabase/migrations/*.sql`, applied in order; `supabase/seed.sql`
  for demo data). Keep the files in git as the source of truth: change the
  schema with a new migration file, then apply it (MCP `apply_migration`, same
  name as the file without the timestamp), never only through the dashboard.
  Migrations 1–5 and the seed are applied (2026-11-22).
  - Test rules by impersonating a user inside a rolled-back transaction:
    `set_config('request.jwt.claims', '{"sub": "<profile id>", "role": "authenticated"}', true)`,
    then `set local role authenticated`, call functions, and end with
    `raise exception` to print results and roll back.
  - App-facing functions are `security definer` and executable by
    `authenticated` on purpose (the advisor warns about each one). Internal
    helpers (`require_role`, `coach_tz`, `coach_today`, `handle_new_user`) are
    not executable by API users; keep it that way for new helpers.
  - Every coach is a real account; there's no "demo coach" special case any more.
  - `coachings` replaces both `ClientStore.clients` and `CoachStore.relations`.
  - Exercise library: **built-in rows (`coach_id` null, read-only) + each coach's own**.
  - Sessions use `timestamptz`; working hours are minutes in the coach's time zone
    (`coach_profiles.timezone`, default Europe/Rome).
  - Booking, coaching and assignment rules are enforced in SQL functions
    (security definer, raising error codes like `slot_unavailable`); RLS only
    governs reads plus a few direct writes (exercises, blocked slots, program delete).
    Clients get a coach's busy times without details from `coach_busy()`.
  - Seed: the prototype's people, programs and calendar as real accounts, all with
    password `password`. Sample coaches can't answer (no auto-accept).
- **App** (Phase 2, in progress). Done: `SupabaseClient`, `Session` (real
  login/signup), `ProgramStore` (programs + exercises), `ClientStore` and
  `CoachStore` (coachings, assignments, directory), `CalendarStore` (hours,
  blocked slots, sessions), live updates, stay logged in. Still to do in
  Phase 2: unit tests.
  - Program, exercise, client (= coaching), coach and session ids are UUID
    strings; `""` means "new" / none (was `0`).
  - `CalendarStore`: a coach loads their own hours, blocked slots and all their
    sessions (no paging by week yet); a client loads their own sessions plus
    their coach's hours and `coach_busy()` for the bookable weeks. Its
    `revision` also changes once a minute (with `now`), so slots turn "past".
    Session times are converted to the device's local day and minutes.
  - C++ lives in `src/` (`supabase/` client, `models/` value types, `stores/`
    QML singletons). Headers use `.hpp`, sources `.cpp`. **Every new C++
    file goes in `SOURCES` of `qt_add_qml_module`**, and its folder in
    `target_include_directories`.
    A C++ store replacing a QML one must also remove the `.qml` file from
    `AURA_QML_SINGLETONS` (same name = conflict).
  - Supabase URL and publishable key are CMake cache variables
    (`AURA_SUPABASE_URL` / `AURA_SUPABASE_KEY`) passed as compile definitions.
  - Stores call `SupabaseClient::instance()->select / insert / update / remove / rpc`
    with `this` as context; `Reply::errorCode` is the SQL function's error code
    (e.g. `slot_unavailable`), an Auth `error_code`, or `network`.
  - Store pattern: derive from `StoreBase` (`src/stores/storebase.*`), implement
    `load()` / `clearData()`, call `start({tables})` at the end of the constructor.
    It loads when the user id changes (`sessionChanged` also fires on token
    refresh) and clears on logout. Writes update the local list first, then go
    through `write()` / `writeRpc()`, **a queue that sends one request at a
    time** (parallel requests can arrive out of order: an "extend" overtook
    its "assign" in testing). On error it emits `errorOccurred(message)` (the
    toast in `Main.qml`) and reloads once the queue is empty; use
    `requestLoad()`, not `load()`, for reloads, so they wait for the queue.
  - Stores tell each other about server changes with `notify("coachings")`
    (`SupabaseClient::notifyChanged`); stores that list that table in `start()`
    reload. E.g. CoachStore accepting a request reloads ClientStore and ProgramStore.
  - **Live updates** (Supabase Realtime, "broadcast from the database"):
    - Triggers (`realtime_on_change()`, migration 4) send `{ "table": … }` to
      each affected user's private channel `user:<profile id>`, once per user
      and table per transaction. No row data travels; the app re-reads
      through the API, so RLS still decides what each user sees. Policy on
      `realtime.messages`: a user can join and read only their own channel.
    - `RealtimeClient` (`src/supabase/realtimeclient.*`, `QWebSocket`, created
      in `main.cpp`) joins that channel while logged in, sends heartbeats and
      refreshed tokens, reconnects with backoff, and turns each message into
      `SupabaseClient::notifyChanged(table)`. After a reconnect it sends `"*"`
      (every store reloads, since messages sent meanwhile are lost).
    - `StoreBase` waits 300 ms after a change notice, then reloads once.
    - **A new table the app shows needs a trigger** (a branch in
      `realtime_on_change()` saying who to notify, via a new migration) and
      the table name in the `start({...})` list of the stores that show it.
    - Your own changes come back as notices too (one extra reload), which keeps
      the same account on two devices in sync.
    - `realtime.messages` partitions are created by the Realtime server: on a
      fresh project the first join can be refused (`MissingPartition`); the
      client retries after 1 s.
  - **C++ store functions don't make QML bindings depend on store data.** A
    binding like `ProgramStore.searchExercises(text, muscle)` only re-runs when
    its arguments change. Each C++ store has a `revision` property; bindings
    that call a function reading store data pass it last:
    `ProgramStore.searchExercises(text, muscle, ProgramStore.revision)`.
    Reading list properties directly (`ProgramStore.programs.find(...)`) is fine.
  - **Editor drafts must be real JS objects.** Return them as `QJSValue` built
    from a `QJsonObject` (`engine->toScriptValue(QJsonObject::fromVariantMap(m))`).
    A `QVariantMap` (or `toScriptValue(QVariantMap)`) gives list wrappers that
    copy elements on read, so in-place edits stop reaching the day cards and rows.
  - Value types (`Q_GADGET` + `QML_VALUE_TYPE(lowercaseName)`) in `src/models`;
    `QList<Gadget>` properties work as Repeater models and support `find`,
    `some`, `filter`, `sort` in QML. Functions taking either a gadget or a JS
    draft use `QVariant` and `T::fromVariant()`.
  - AUTOMOC only notices `Q_OBJECT` / `Q_GADGET` at the start of a line.
  - **Full C++ stores** (user's choice, wants C++ and future unit tests): each store
    becomes a C++ QML singleton with the same functions, so screens change little.
  - Data reaches QML as **typed value types** (`Q_GADGET` structs), so screens keep
    reading `client.name` / `modelData.name`. The program and working-hours
    editors need rework, because they edit their draft in place.
  - One C++ `SupabaseClient` for auth (email/password, token refresh), PostgREST
    reads and RPC calls, plus `RealtimeClient` for live updates; Qt Network and
    Qt WebSockets only (both machines need the Qt WebSockets add-on), same code
    on macOS and Windows.
  - Changes apply locally at once with client-generated UUIDs, then go to the
    server; on error, revert and show the error.
  - **Stay logged in** (`SessionStorage`, `src/supabase/sessionstorage.*`):
    - The Supabase refresh token is saved in the system's secure storage
      through **QtKeychain** (macOS Keychain, Windows Credential Manager entry
      `supabase-session:<project host>@<app name>`). QtKeychain 0.18.0 is
      downloaded and built as a static library by CMake (`FetchContent`,
      pinned by SHA-256), so the first configure on a machine needs internet.
    - At startup `Session` resumes it (`Session.restoring` → splash in
      `Main.qml`), then loads the profile like a login. Every new refresh
      token is saved (Supabase rotates them); logout or a rejected token
      deletes it. A network error keeps it for the next launch.
    - Only the first running copy stays logged in (lock file in the app data
      folder): Supabase revokes the whole login when a rotated token is used
      twice, which two copies sharing one saved token would do.
    - `AURA_NO_SAVED_LOGIN=1` turns it off (test drivers that log in by
      themselves, so a restore doesn't race their login).

## Architecture

- `main.cpp` loads module `qt_aura`. `Main.qml` is the window plus a router (`Loader`):
  no user → `AuthFlow`; coach → `CoachHome`; client → `ClientHome`.
- `AppShell` is the frame for both apps: a sidebar on wide screens (≥ 820 px), a
  top bar plus bottom tab bar on narrow ones. Pages are children, shown by index.
  It takes `navItems`, `compactNavItems` (short labels for phones) and
  `navBadges`, a list per menu item of `{count, tone: "primary"|"danger", label}`.
- **Tab order is used by index.** Pages navigate with `navigateRequested(index)`:
  - coach: 0 Dashboard, 1 Clients, 2 Calendar, 3 Programs, 4 Exercises, 5 Messages;
  - client: 0 Home, 1 My coach, 2 Calendar, 3 My program, 4 Progress, 5 Messages.

  If you reorder tabs, update the index constants in pages (`calendarTab`,
  `coachTab`, `messagesTab`, `programTab`, …).
- Sections that go one level deep use a `StackView`: `ClientsSection` (list →
  detail), `ProgramsSection` (list → editor). `ProgramsSection.openProgram(id, backText)`
  opens a program from another section (from a client's page); the back button
  then returns there.
- **Stores (C++ singletons in `src/stores/`) own all data and rules. Screens
  only call them.** Keep it that way. Bindings calling store functions pass the
  store's `revision` (see "Backend").
- `README.md` has two Mermaid diagrams (architecture, and how a change reaches
  another device). Update them when you add a store, a backend class or a
  connection between them.

| Store | Responsibility |
|---|---|
| `Session` | **C++** (`src/stores/session.*`), Supabase Auth: `login`, `signup`, `logout`, `user {id,name,email,role}` (`AuraUser` value type, empty id when logged out), `busy`, `lastError`, `restoring` (resuming the saved login at startup) |
| `ClientStore` | **C++** (`src/stores/clientstore.*`, models in `src/models/coaching.*`): the coach's clients (invited / active / paused coachings) + assignments, or the client's own coaching (`clientByEmail(Session.user.email)`); program status (`none`/`scheduled`/`active`/`endingSoon`/`expired`), invite, assign / extend / end, date helpers |
| `ProgramStore` | **C++** (`src/stores/programstore.*`, models in `src/models/program.*`): programs (days → exercise entries) and exercise library (built-in = read-only), per-week changes, display helpers. Editor drafts are JS objects |
| `CalendarStore` | **C++** (`src/stores/calendarstore.*`, models in `src/models/calendar.*`): the coach's working hours, blocked slots and sessions; the client's sessions and their coach's free slots; slot states, booking rules, requests / confirm / decline / cancel |
| `CoachStore` | **C++** (`src/stores/coachstore.*`): coach directory (with working hours), `myRelation` / `myCoach` for a client (requests, invitations, leave), `myProfile` / `isPublic` / `pendingRequests` / `setVisibility` for a coach |
| `MockData` | Leftover sample content for dashboards (stats, today checklist, goals, coach message) |

- All data is real and per account. In the seed, Giulia Rossi (`coach@aura.app`)
  is the coach with clients, programs and a calendar; the other coaches have
  hours but no clients.

## Business rules (as implemented)

**Programs**
- A program has `weeks` and `days[]`. Each day has exercise entries
  `{exerciseId, sets, reps, load, rest, notes, weeks: {"4": {sets, reps, load}}}`.
- Only `sets`, `reps` and `load` can change per week (`ProgramStore.weeklyKeys`).
  Setting the all-weeks value removes that week's change.
- An assignment copies the program's name and number of weeks when it's assigned.
  If it's extended past the program's length, the extra weeks repeat the last
  program week (`ProgramStore.programWeekFor`).

**Assignments and status**
- `endingSoon` means fewer than 7 days left.
- An expired assignment stays "current" until the coach assigns a new program or
  extends it.
- History end reasons: `completed`, `replaced`, `ended`.

**Coach ↔ client**
- **Public** coach: listed in the directory; clients send requests and the coach
  accepts or declines them (`CoachStore.pendingRequests`, `ClientRequestsDialog`).
- **Private** coach: not listed; invites by email (a `ClientStore` client with
  status `invited`); the client accepts or declines in **My coach**.
- Switching to private declines all waiting requests.
- Nobody accepts automatically: the coach answers from their own account.
  A coach that isn't `accepting` can't be requested (`coach_not_available`).

**Calendar and bookings**
- Everything works in 30-minute slots. The grid always shows 07:00–21:00
  (`defaultFrom` / `defaultTo`) and grows to fit hours or sessions outside that.
- A slot is free when it's in working hours, not blocked, not taken by a
  confirmed or pending session, and at least 60 min away (`minNoticeMinutes`).
- Clients book **any length from 30 min to 3 h** (`maxSessionMinutes`), up to
  4 weeks ahead (`bookingWeeks`). They do this by clicking or dragging in
  `ClientBookingCalendar`; on phones they tap, then use − / +.
- **Every booking is `pending` until the coach confirms or declines it. Nobody
  auto-confirms.** A pending booking holds its slot. Clients can only book
  their own (active) coach. The server checks every rule again
  (`request_session`).
- Session statuses: `confirmed`, `pending`, `declined`, `cancelled` (with
  `cancelledBy: "client"|"coach"`).
- Clients can cancel only ≥ 24 h before the start (`cancelNoticeHours`); this
  applies to requests too. Coaches can cancel confirmed upcoming sessions.
- In the coach's calendar, **clicking any session opens its details**
  (`BookingRequestsDialog.openFor`), with actions that depend on its status.
  There's no menu. Session blocks carry a badge: **Respond** on requests, **⋯** on
  confirmed sessions.

## User decisions (don't undo)

- **Menu badges:** **Clients** shows green (primary) for coaching requests and
  red (danger) for expired programs; **Calendar** shows green for booking
  requests. Requests are always primary green; problems are red.
- **Banners on the coach's Clients page were removed on purpose**: the user deleted
  the red "expired programs" banner, and asked for the green "requests" banner to
  become a badge instead. Don't add banners back there. (`ClientsHome` still has an
  unused `expiredCount` property from the user's edit; leave it unless asked.)
- The exercise library is its own sidebar entry (**Exercises**), not a tab in Programs.
- **Working hours** are edited in a dialog opened from the Calendar header
  (same pattern as **Invite client**), not in a tab.
- The client tab is **"My program"** (not "My plan"), and the client **"Calendar"**
  replaced "Sessions".
- The default window is 1920×1080, shrunk to fit smaller screens.
- Exercise images: the user looked at libraries (wger, RepDB, …) and generating
  images, and said "nevermind". Don't pursue it unless asked.

## QML conventions and pitfalls (learned the hard way)

**Styling and structure**
- Import `QtQuick.Controls.Basic` (customisable). Never hard-code colors or
  sizes; use `Theme.*`, including `Theme.toneColor` / `toneSoftColor` for tones
  `primary` / `accent` / `danger` / `neutral`.
- Start every file with a comment saying what it is. Put `qsTr()` around all
  visible text.
- Use `pragma ComponentBehavior: Bound` in files with delegates. Delegates declare
  `required property …` and reference each other by **id**, never `parent.parent`.

**Naming collisions**
- **Name generic components with an `Aura` prefix.** Qt 6.10 added a
  `SearchField` that silently replaced ours, hence `AuraSearchField`. Qt.labs
  also has a `Theme` (harmless, since it isn't imported).
- **Never give a property a name starting with `on` + a capital letter**
  (`onPrimary` was parsed as a signal handler → `textOnPrimary`).
- Don't declare signals named `accepted` / `rejected` on a `Dialog` (they clash
  with the built-ins). Use names like `clientAccepted`.
- Item has a `state` property; don't use it as a custom name (use `state_` or
  `slotState`).

**Layouts and bindings**
- Nested layouts fill width by default. Fixed-width fields inside a
  `GridLayout`/`RowLayout` need `Layout.fillWidth: false`.
- Editors that change text in place (`ProgramEditor`, `WorkingHoursEditor`):
  - change the draft in place and bump a `revision` int, passed as an extra
    (ignored) function argument so bindings refresh. Rebuilding the draft on
    every keystroke would lose focus, or destroy a held repeat button.
  - Structural edits (add, move, remove) replace the draft.
- Repeaters over JS arrays give delegates a **copy** in `modelData`. Write through
  the store or editor by index, not into `modelData`.
- Popups and dialogs: `AuraDialog` (title, `actions`, `leftActions`, scrollable
  body; no title = no header), `ConfirmDialog`, `AuraMenu` (an `Action` with
  `objectName: "destructive"` shows in red). A `Toast` must be a child of a plain
  `Item` root, not inside a `ScrollView`.
- Singletons can be read before their bindings update, e.g. right after login.
  Components that depend on them should react to changes (`onCoachIdChanged`),
  not only run once in `Component.onCompleted`.
- Prefer `popup(item, x, y)` to `popup()` for menus: the cursor position is wrong
  on touch screens and in tests.

## Known gaps and open questions

**Gaps**
- Not designed yet: **Messages** (both apps) and **Progress** (client).
- The client **Home** still uses `MockData` (sessions completed, goals, coach
  message), even for clients without a coach.
- Clients get no notification or badge when the coach confirms, declines or
  cancels a booking, or accepts a request.
- On phones, the booking "Request" bar sits below the grid (it could be pinned).
- The **⋯** badge on confirmed sessions dates from the old menu. It may get
  removed or turned into something meaningful.
- `SegmentedTabs` is no longer used anywhere.
- Coaches can't edit their public profile (bio, price, …) in the app yet; it's
  in `coach_profiles` (the seed fills it).
- Dates are the device's local days; the server uses the coach's time zone
  (`coach_today`). They only differ for devices outside Europe/Rome.
- Live updates reload a whole store on each change notice. Fine at this size;
  with many clients, reload only what changed (the trigger could send the
  row id).
- The client's directory of public coaches isn't live (only the client's own
  coach notifies them).
- The coach's calendar loads all their sessions at once; it needs paging by
  week once there are many.

**Open product questions** (ask the user rather than guess)
- Should coaches be able to open one-off extra hours, or take multi-day time off?
- Should clients get notification badges on their Calendar / My coach tabs?
- Session length per type, or always free?
- Supersets / circuits in programs?
- Reviews or ratings in the directory (they need moderation)?
