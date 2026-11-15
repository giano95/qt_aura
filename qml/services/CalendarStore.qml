pragma Singleton
import QtQuick

// The coach's availability and booked sessions.
//
// PHASE 0: in-memory mock. In Phase 2 this becomes a C++ repository backed by
// the API (tables: working_hours, blocked_slots, sessions).
//
// Data shapes
//   weeklyHours: { "<day>": [ { start, end } ] }   day: 0 = Sunday ... 6 = Saturday,
//                start/end in minutes from midnight, sorted, not overlapping
//   blocked:     { "yyyy-MM-dd": [ minute, ... ] }  slot starts the coach made unavailable
//   session:     { id, coachId, dateKey, start, end, client, clientEmail, type, mode,
//                  note, status, requestedAt, cancelledBy }
//                start/end: minutes from midnight, any length in 30-minute steps
//                status: "confirmed" | "pending" (booked by a client, waiting for the
//                coach) | "declined" | "cancelled". Only confirmed and pending
//                sessions take up time. Every booking needs the coach's approval.
//
// The calendar works in 30-minute slots. A slot is available when it lies
// inside the working hours of its weekday, isn't blocked, isn't booked and
// hasn't passed.
//
// Working hours and blocked slots belong to the demo coach (CoachStore's
// coach 1). Clients can also book the other sample coaches: their hours come
// from CoachStore. They have no account in the prototype, so their bookings
// stay pending.
QtObject {
    id: store

    readonly property int slotMinutes: 30
    readonly property int dayMs: 86400000

    property var weeklyHours: ({
        "1": [ { start: 540, end: 1080 } ],
        "2": [ { start: 540, end: 1080 } ],
        "3": [ { start: 540, end: 1080 } ],
        "4": [ { start: 540, end: 1080 } ],
        "5": [ { start: 540, end: 1080 } ],
        "6": [],
        "0": []
    })
    property var blocked: ({})
    property var sessions: []

    // Re-evaluated once a minute so slots turn "past" while the app is open
    property double now: Date.now()
    property Timer _clock: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: store.now = Date.now()
    }

    // ---- dates --------------------------------------------------------------

    function dateKey(ms) {
        return Qt.formatDate(new Date(ms), "yyyy-MM-dd")
    }

    function startOfDay(ms) {
        const d = new Date(ms)
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    }

    function addDays(ms, days) {
        const d = new Date(ms)
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days).getTime()
    }

    // Monday (midnight) of the week containing `ms`
    function mondayOf(ms) {
        const d = new Date(ms)
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7).getTime()
    }

    function formatMinutes(minutes) {
        const h = Math.floor(minutes / 60)
        const m = minutes % 60
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }

    // ---- working hours ------------------------------------------------------

    function rangesFor(dayMs) {
        return weeklyHours[String(new Date(dayMs).getDay())] || []
    }

    function isWorkingSlot(dayMs, minute) {
        return rangesFor(dayMs).some(r => minute >= r.start && minute + slotMinutes <= r.end)
    }

    function cloneHours() {
        return JSON.parse(JSON.stringify(weeklyHours))
    }

    function saveWeeklyHours(hours) {
        const clean = {}
        for (let d = 0; d < 7; ++d)
            clean[String(d)] = (hours[String(d)] || []).slice().sort((a, b) => a.start - b.start)
        weeklyHours = clean
    }

    // Hours per week in a weeklyHours-shaped object
    function totalWeeklyMinutes(hours) {
        let total = 0
        for (let d = 0; d < 7; ++d)
            (hours[String(d)] || []).forEach(r => total += r.end - r.start)
        return total
    }

    // Problems in a day's ranges, or "" if fine
    function rangeProblem(ranges) {
        const sorted = ranges.slice().sort((a, b) => a.start - b.start)
        for (let i = 0; i < sorted.length; ++i) {
            if (sorted[i].end <= sorted[i].start)
                return qsTr("A time range ends before it starts.")
            if (i > 0 && sorted[i].start < sorted[i - 1].end)
                return qsTr("Two time ranges overlap.")
        }
        return ""
    }

    // ---- blocked slots ------------------------------------------------------

    function isBlocked(dayMs, minute) {
        const list = blocked[dateKey(dayMs)]
        return list !== undefined && list.includes(minute)
    }

    // Blocks or frees several slots of one day in a single change
    function setBlocked(dayMs, minutes, value) {
        const key = dateKey(dayMs)
        const next = Object.assign({}, blocked)
        const set = new Set(next[key] || [])
        minutes.forEach(m => value ? set.add(m) : set.delete(m))
        if (set.size === 0)
            delete next[key]
        else
            next[key] = Array.from(set).sort((a, b) => a - b)
        blocked = next
    }

    // ---- sessions -----------------------------------------------------------

    readonly property int sessionMinutes: 60          // default length
    readonly property int maxSessionMinutes: 180
    // Clients can cancel up to this long before the start
    readonly property int cancelNoticeHours: 24
    // Bookings must start at least this far in the future
    readonly property int minNoticeMinutes: 60
    // Clients can book this many weeks ahead (including the current one)
    readonly property int bookingWeeks: 4

    function isActive(session) {
        return session.status === "confirmed" || session.status === "pending"
    }

    // The demo coach's confirmed and pending sessions on a day (coach calendar)
    function sessionsOn(dayMs) {
        return coachSessionsOn(CoachStore.demoCoachId, dayMs)
    }

    function sessionAt(dayMs, minute) {
        return sessionsOn(dayMs).find(s => minute >= s.start && minute < s.end) || null
    }

    function coachSessionsOn(coachId, dayMs) {
        const key = dateKey(dayMs)
        return sessions.filter(s => s.coachId === coachId && s.dateKey === key && isActive(s))
                       .sort((a, b) => a.start - b.start)
    }

    function sessionById(id) {
        return sessions.find(s => s.id === id) || null
    }

    // Start of a session as a timestamp
    function startMs(session) {
        const p = session.dateKey.split("-").map(Number)
        return new Date(p[0], p[1] - 1, p[2]).getTime() + session.start * 60000
    }

    function endMs(session) {
        return startMs(session) + (session.end - session.start) * 60000
    }

    // A client's sessions (any status), oldest first. Sessions created before
    // emails were stored are matched by name.
    function clientSessions(email, name) {
        const e = (email || "").toLowerCase()
        return sessions.filter(s => (s.clientEmail && s.clientEmail === e) || (!s.clientEmail && s.client === name))
                       .sort((a, b) => startMs(a) - startMs(b))
    }

    // The client's next confirmed or pending session, or null
    function nextSessionFor(email, name) {
        return clientSessions(email, name).find(s => isActive(s) && endMs(s) > now) || null
    }

    // Bookings waiting for the demo coach, soonest first
    readonly property var pendingBookings: sessions
        .filter(s => s.coachId === CoachStore.demoCoachId && s.status === "pending" && endMs(s) > now)
        .sort((a, b) => startMs(a) - startMs(b))

    // ---- booking (client side) ---------------------------------------------

    // Inside the coach's working hours (free or not)
    function isCoachWorkingSlot(coachId, dayMs, minute) {
        if (coachId === CoachStore.demoCoachId)
            return isWorkingSlot(dayMs, minute)
        const coach = CoachStore.coachById(coachId)
        const ranges = coach ? (coach.weeklyHours[String(new Date(dayMs).getDay())] || []) : []
        return ranges.some(r => minute >= r.start && minute + slotMinutes <= r.end)
    }

    // Every 30-minute slot from start to end (exclusive) is free
    function isRangeFree(coachId, dayMs, start, end) {
        for (let m = start; m < end; m += slotMinutes)
            if (!isCoachSlotFree(coachId, dayMs, m))
                return false
        return end > start
    }

    // Grid hours for a coach's week: like visibleRange, for any coach
    function coachVisibleRange(coachId, mondayMs) {
        if (coachId === CoachStore.demoCoachId)
            return visibleRange(mondayMs)
        const coach = CoachStore.coachById(coachId)
        let from = defaultFrom
        let to = defaultTo
        for (let i = 0; i < 7; ++i) {
            const day = addDays(mondayMs, i)
            const ranges = coach ? (coach.weeklyHours[String(new Date(day).getDay())] || []) : []
            ranges.forEach(r => { from = Math.min(from, r.start); to = Math.max(to, r.end) })
            coachSessionsOn(coachId, day).forEach(x => { from = Math.min(from, x.start); to = Math.max(to, x.end) })
        }
        return { from: Math.floor(from / 60) * 60, to: Math.min(24 * 60, Math.ceil(to / 60) * 60) }
    }

    // A client can cancel a confirmed or pending session up to 24 h before it
    function canClientCancel(session) {
        return isActive(session) && startMs(session) - now >= cancelNoticeHours * 3600000
    }

    function durationText(minutes) {
        const h = Math.floor(minutes / 60)
        const m = minutes % 60
        if (h === 0)
            return qsTr("%1 min").arg(m)
        return m === 0 ? qsTr("%1 h").arg(h) : qsTr("%1 h %2 min").arg(h).arg(m)
    }

    // Can a session of coach `coachId` use this 30-minute slot?
    function isCoachSlotFree(coachId, dayMs, minute) {
        if (dayMs + minute * 60000 < now + minNoticeMinutes * 60000)
            return false
        if (coachId === CoachStore.demoCoachId)
            return slotState(dayMs, minute) === "available"
        const coach = CoachStore.coachById(coachId)
        if (!coach)
            return false
        const ranges = coach.weeklyHours[String(new Date(dayMs).getDay())] || []
        if (!ranges.some(r => minute >= r.start && minute + slotMinutes <= r.end))
            return false
        return !coachSessionsOn(coachId, dayMs).some(s => minute >= s.start && minute < s.end)
    }

    // Start times (minutes) where a session of `duration` minutes fits entirely
    // in free slots
    function bookableStarts(coachId, dayMs, duration) {
        const starts = []
        for (let m = 0; m + duration <= 24 * 60; m += slotMinutes) {
            let free = true
            for (let k = m; k < m + duration && free; k += slotMinutes)
                free = isCoachSlotFree(coachId, dayMs, k)
            if (free)
                starts.push(m)
        }
        return starts
    }

    // Sends a booking request (start/end in minutes); returns the session id.
    // It stays pending until the coach confirms or declines it.
    function requestSession(coachId, dayMs, start, end, type, mode, note, clientName, clientEmail) {
        const id = _nextSessionId()
        const session = {
            id: id, coachId: coachId, dateKey: dateKey(dayMs),
            start: start, end: end,
            client: clientName, clientEmail: (clientEmail || "").toLowerCase(),
            type: type, mode: mode, note: (note || "").trim(),
            status: "pending", requestedAt: Date.now(), cancelledBy: ""
        }
        sessions = sessions.concat([session])
        return id
    }

    function confirmSession(id) {
        _setStatus(id, "confirmed")
    }

    function declineSession(id) {
        _setStatus(id, "declined")
    }

    // by: "client" | "coach"
    function cancelSession(id, by) {
        sessions = sessions.map(s => s.id === id ? Object.assign({}, s, { status: "cancelled", cancelledBy: by || "client" }) : s)
    }

    function statusText(session) {
        switch (session.status) {
        case "pending": return qsTr("Waiting for confirmation")
        case "declined": return qsTr("Declined")
        case "cancelled": return session.cancelledBy === "coach" ? qsTr("Cancelled by your coach") : qsTr("Cancelled")
        default: return qsTr("Confirmed")
        }
    }

    function statusTone(session) {
        switch (session.status) {
        case "pending": return "accent"
        case "declined": return "danger"
        case "cancelled": return "neutral"
        default: return "primary"
        }
    }

    function _setStatus(id, status) {
        sessions = sessions.map(s => s.id === id ? Object.assign({}, s, { status: status }) : s)
    }

    property int _lastSessionId: 1000
    function _nextSessionId() {
        _lastSessionId += 1
        return _lastSessionId
    }



    // ---- slots --------------------------------------------------------------

    function isPast(dayMs, minute) {
        return dayMs + (minute + slotMinutes) * 60000 <= now
    }

    // "booked" | "outside" | "blocked" | "available"
    function slotState(dayMs, minute) {
        if (sessionAt(dayMs, minute))
            return "booked"
        if (!isWorkingSlot(dayMs, minute))
            return "outside"
        return isBlocked(dayMs, minute) ? "blocked" : "available"
    }

    // A slot the coach can block or free right now
    function isToggleable(dayMs, minute) {
        const state = slotState(dayMs, minute)
        return (state === "available" || state === "blocked") && !isPast(dayMs, minute)
    }

    // Hours the week grid always shows (07:00 to 21:00, so the last row is 20:00)
    readonly property int defaultFrom: 7 * 60
    readonly property int defaultTo: 21 * 60

    // Minutes shown in the week grid: at least defaultFrom–defaultTo, extended
    // to whole hours when working hours or sessions of that week go beyond
    function visibleRange(mondayMs) {
        let from = defaultFrom
        let to = defaultTo
        for (let i = 0; i < 7; ++i) {
            const day = addDays(mondayMs, i)
            rangesFor(day).forEach(r => { from = Math.min(from, r.start); to = Math.max(to, r.end) })
            sessionsOn(day).forEach(s => { from = Math.min(from, s.start); to = Math.max(to, s.end) })
        }
        return {
            from: Math.max(0, Math.floor(from / 60) * 60),
            to: Math.min(24 * 60, Math.ceil(to / 60) * 60)
        }
    }

    // Totals for the week starting on `mondayMs`, counting slots that haven't passed
    function weekStats(mondayMs) {
        let available = 0
        let blockedCount = 0
        let booked = 0
        for (let i = 0; i < 7; ++i) {
            const day = addDays(mondayMs, i)
            for (let m = 0; m < 24 * 60; m += slotMinutes) {
                if (isPast(day, m))
                    continue
                const state = slotState(day, m)
                if (state === "available")
                    ++available
                else if (state === "blocked")
                    ++blockedCount
            }
            booked += sessionsOn(day).filter(s => !isPast(day, s.end - slotMinutes)).length
        }
        return {
            availableHours: available * slotMinutes / 60,
            blockedHours: blockedCount * slotMinutes / 60,
            sessions: booked
        }
    }

    function hoursText(hours) {
        return hours === 1 ? qsTr("1 h") : qsTr("%1 h").arg(Number.isInteger(hours) ? hours : hours.toFixed(1))
    }

    // ---- sample data --------------------------------------------------------

    Component.onCompleted: {
        const today = startOfDay(Date.now())
        let id = 1
        const list = []
        const modes = [qsTr("In person"), qsTr("Video call")]
        const add = (dayMs, start, minutes, client, type) =>
            list.push({ id: id++, coachId: 1, dateKey: dateKey(dayMs), start: start, end: start + minutes,
                        client: client, clientEmail: "", type: type, mode: modes[id % 2],
                        note: "", status: "confirmed", requestedAt: 0, cancelledBy: "" })

        // Today: the same sessions as the coach dashboard
        add(today, 9 * 60, 60, "Luca Bianchi", qsTr("Monthly review"))
        add(today, 10 * 60 + 30, 60, "Sara Conti", qsTr("Goal setting"))
        add(today, 14 * 60, 60, "Marco Ferri", qsTr("Weekly check-in"))
        add(today, 17 * 60 + 30, 60, "Elena Greco", qsTr("First session"))

        // Other weekdays, two weeks back and two forward
        const clients = ["Giorgia Marino", "Matteo Fontana", "Andrea Gallo", "Chiara Moretti", "Luca Bianchi", "Sara Conti", "Davide Russo"]
        const types = [qsTr("Training"), qsTr("Weekly check-in"), qsTr("Technique session")]
        const times = [9 * 60, 11 * 60, 15 * 60, 16 * 60 + 30]
        for (let offset = -14; offset <= 14; ++offset) {
            if (offset === 0)
                continue
            const day = addDays(today, offset)
            const weekday = new Date(day).getDay()
            if (weekday === 0 || weekday === 6)
                continue
            // 1–3 sessions, each at a different time of the day
            const count = 1 + Math.abs(offset * 7 + weekday) % 3
            const first = Math.abs(offset + weekday) % times.length
            for (let k = 0; k < count; ++k) {
                const n = Math.abs(offset * 3 + k * 5 + weekday)
                add(day, times[(first + k) % times.length], 60, clients[n % clients.length], types[n % types.length])
            }
        }
        sessions = list

        // A few blocked slots in the coming days: a long lunch and an early Friday finish
        const next = {}
        for (let offset = 1; offset <= 10; ++offset) {
            const day = addDays(today, offset)
            const weekday = new Date(day).getDay()
            if (weekday === 3 && !next.wed)
                next.wed = day
            if (weekday === 5 && !next.fri)
                next.fri = day
        }
        const blockedSeed = {}
        if (next.wed)
            blockedSeed[dateKey(next.wed)] = [12 * 60, 12 * 60 + 30, 13 * 60, 13 * 60 + 30]
        if (next.fri)
            blockedSeed[dateKey(next.fri)] = [15 * 60, 15 * 60 + 30, 16 * 60, 16 * 60 + 30, 17 * 60, 17 * 60 + 30]
        blocked = blockedSeed

        // Three bookings waiting for the coach, in free slots of the coming days
        const requests = [
            { client: "Luca Bianchi", email: "client@aura.app", type: qsTr("Technique session"), minutes: 90, note: "Can we look at my squat depth?" },
            { client: "Sara Conti", email: "sara.conti@example.com", type: qsTr("Weekly check-in"), minutes: 30, note: "" },
            { client: "Matteo Fontana", email: "matteo.fontana@example.com", type: qsTr("Training"), minutes: 60, note: "Lower back is better, ready to train." }
        ]
        let r = 0
        for (let offset = 2; offset <= 12 && r < requests.length; ++offset) {
            const day = addDays(today, offset)
            const q = requests[r]
            const starts = bookableStarts(1, day, q.minutes)
            if (starts.length === 0)
                continue
            ++r
            const start = starts[Math.floor(starts.length / 2)]
            sessions = sessions.concat([{
                id: _nextSessionId(), coachId: 1, dateKey: dateKey(day), start: start, end: start + q.minutes,
                client: q.client, clientEmail: q.email, type: q.type, mode: modes[r % 2], note: q.note,
                status: "pending", requestedAt: Date.now() - r * 5 * 3600000, cancelledBy: ""
            }])
            offset += 1     // spread them over different days
        }
    }
}
