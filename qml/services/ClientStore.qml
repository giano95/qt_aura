pragma Singleton
import QtQuick

// The coach's clients and the programs assigned to them.
//
// PHASE 0: in-memory mock. In Phase 2 this becomes a C++ repository backed by
// the API (tables: clients, program_assignments).
//
// Data shapes
//   client:     { id, name, email, phone, goal, status, since (ms), lastCheckIn (ms | 0),
//                 nextSession (ms | 0), assignments: [ assignment ] }
//               status: "active" | "paused" | "invited"
//   assignment: { id, programId, programName, weeks, start (ms, midnight), note,
//                 endedAt (ms | 0), endReason: "" | "completed" | "replaced" | "ended" }
//
// The current assignment is the last one without endedAt. Once its last day
// has passed it stays current but counts as expired, until the coach assigns
// a new program or extends it.
QtObject {
    id: store

    readonly property int dayMs: 86400000

    property var clients: []

    // ---- dates --------------------------------------------------------------

    function today() {
        const d = new Date()
        d.setHours(0, 0, 0, 0)
        return d.getTime()
    }

    // Midnight `days` days from today (negative = past)
    function dayOffset(days) {
        const d = new Date()
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + days)
        return d.getTime()
    }

    function nextMonday() {
        const d = new Date()
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + ((8 - d.getDay()) % 7 || 7))
        return d.getTime()
    }

    // Last day of an assignment (inclusive)
    function lastDay(assignment) {
        const d = new Date(assignment.start)
        d.setDate(d.getDate() + assignment.weeks * 7 - 1)
        return d.getTime()
    }

    function daysBetween(fromMs, toMs) {
        return Math.round((toMs - fromMs) / dayMs)
    }

    function formatDay(ms) {
        return Qt.formatDate(new Date(ms), "ddd d MMM")
    }

    function formatDayLong(ms) {
        return Qt.formatDate(new Date(ms), "ddd d MMM yyyy")
    }

    function relativeDay(ms) {
        if (!ms)
            return qsTr("Never")
        const day = new Date(ms)
        day.setHours(0, 0, 0, 0)
        const days = daysBetween(day.getTime(), today())
        if (days === 0)
            return qsTr("Today")
        if (days === 1)
            return qsTr("Yesterday")
        if (days === -1)
            return qsTr("Tomorrow")
        if (days > 0)
            return qsTr("%1 days ago").arg(days)
        return qsTr("In %1 days").arg(-days)
    }

    // ---- reading ------------------------------------------------------------

    function clientById(id) {
        return clients.find(c => c.id === id) || null
    }

    // The client record behind a logged-in client account (null if the coach
    // hasn't added them yet). Phase 2: the API returns this for the session.
    function clientByEmail(email) {
        const e = (email || "").trim().toLowerCase()
        return clients.find(c => c.email.toLowerCase() === e) || null
    }

    function currentAssignment(client) {
        for (let i = client.assignments.length - 1; i >= 0; --i)
            if (!client.assignments[i].endedAt)
                return client.assignments[i]
        return null
    }

    // Finished assignments, newest first
    function pastAssignments(client) {
        return client.assignments.filter(a => a.endedAt).sort((a, b) => b.start - a.start)
    }

    // Where the client stands with their program.
    // kind: "none" | "scheduled" | "active" | "endingSoon" | "expired"
    function programStatus(client) {
        const a = currentAssignment(client)
        if (!a)
            return { kind: "none", assignment: null }
        const t = today()
        const last = lastDay(a)
        if (t < a.start)
            return { kind: "scheduled", assignment: a, daysUntil: daysBetween(t, a.start), lastDay: last }
        if (t > last)
            return { kind: "expired", assignment: a, daysAgo: daysBetween(last, t), lastDay: last }
        const daysLeft = daysBetween(t, last)
        return {
            kind: daysLeft < 7 ? "endingSoon" : "active",
            assignment: a,
            week: Math.floor(daysBetween(a.start, t) / 7) + 1,
            daysLeft: daysLeft,
            progress: (daysBetween(a.start, t) + 1) / (a.weeks * 7),
            lastDay: last
        }
    }

    // Short label and color tone for a status, for chips
    function statusText(status) {
        switch (status.kind) {
        case "none":
            return qsTr("No program")
        case "scheduled":
            return status.daysUntil === 1 ? qsTr("Starts tomorrow") : qsTr("Starts in %1 days").arg(status.daysUntil)
        case "expired":
            return status.daysAgo === 1 ? qsTr("Expired yesterday") : qsTr("Expired %1 days ago").arg(status.daysAgo)
        case "endingSoon":
            return status.daysLeft === 0 ? qsTr("Ends today")
                 : status.daysLeft === 1 ? qsTr("Ends tomorrow")
                 : qsTr("Ends in %1 days").arg(status.daysLeft)
        default:
            return qsTr("Week %1 of %2").arg(status.week).arg(status.assignment.weeks)
        }
    }

    function statusTone(status) {
        switch (status.kind) {
        case "expired": return "danger"
        case "endingSoon": return "accent"
        case "none": return "neutral"
        default: return "primary"
        }
    }

    function endReasonText(reason) {
        switch (reason) {
        case "completed": return qsTr("Completed")
        case "replaced": return qsTr("Replaced")
        case "ended": return qsTr("Ended early")
        default: return ""
        }
    }

    // filter: "all" | "expired" | "endingSoon" | "none" | "invited" | "paused"
    function matchesFilter(client, filter) {
        const kind = programStatus(client).kind
        switch (filter) {
        case "expired": return kind === "expired"
        case "endingSoon": return kind === "endingSoon"
        case "none": return kind === "none" && client.status !== "invited"
        case "invited": return client.status === "invited"
        case "paused": return client.status === "paused"
        default: return true
        }
    }

    function search(query, filter) {
        const q = (query || "").trim().toLowerCase()
        return clients
            .filter(c => matchesFilter(c, filter))
            .filter(c => {
                if (!q)
                    return true
                const a = currentAssignment(c)
                return c.name.toLowerCase().includes(q)
                    || c.email.toLowerCase().includes(q)
                    || (a !== null && a.programName.toLowerCase().includes(q))
            })
            .sort((a, b) => a.name.localeCompare(b.name))
    }

    function count(filter) {
        return clients.filter(c => matchesFilter(c, filter)).length
    }

    // Clients currently following (or about to start) the program
    function countForProgram(programId) {
        return clients.filter(c => {
            const s = programStatus(c)
            return s.assignment !== null && s.assignment.programId === programId && s.kind !== "expired"
        }).length
    }

    function isEmailTaken(email) {
        const e = email.trim().toLowerCase()
        return clients.some(c => c.email.toLowerCase() === e)
    }

    // ---- changes ------------------------------------------------------------

    // Assigns `programId` starting on `startMs`. The current program, if any,
    // moves to the history.
    function assign(clientId, programId, startMs, note) {
        const program = ProgramStore.programs.find(p => p.id === programId)
        if (!program)
            return
        _update(clientId, client => {
            const current = currentAssignment(client)
            if (current) {
                const status = programStatus(client)
                if (status.kind === "expired") {
                    current.endedAt = status.lastDay
                    current.endReason = "completed"
                } else if (status.kind === "scheduled") {
                    // Never started: drop it instead of keeping it in the history
                    client.assignments = client.assignments.filter(a => a.id !== current.id)
                } else {
                    current.endedAt = today()
                    current.endReason = "replaced"
                }
            }
            client.assignments.push({
                id: _nextId(),
                programId: program.id,
                programName: program.name,
                weeks: ProgramStore.weekCount(program),
                start: startMs,
                note: (note || "").trim(),
                endedAt: 0,
                endReason: ""
            })
            if (client.status === "paused")
                client.status = "active"
        })
    }

    function extend(clientId, weeks) {
        _update(clientId, client => {
            const current = currentAssignment(client)
            if (current)
                current.weeks += weeks
        })
    }

    // Ends the current program today (or removes it if it hasn't started)
    function endProgram(clientId) {
        _update(clientId, client => {
            const current = currentAssignment(client)
            if (!current)
                return
            const kind = programStatus(client).kind
            if (kind === "scheduled") {
                client.assignments = client.assignments.filter(a => a.id !== current.id)
            } else if (kind === "expired") {
                current.endedAt = lastDay(current)
                current.endReason = "completed"
            } else {
                current.endedAt = today()
                current.endReason = "ended"
            }
        })
    }

    // Returns the new client's id
    function invite(name, email, goal) {
        return addClient(name, email, goal, "invited")
    }

    // Adds a client with the given status ("invited" or "active"); returns the id
    function addClient(name, email, goal, status) {
        const client = {
            id: _nextId(),
            name: name.trim(),
            email: email.trim().toLowerCase(),
            phone: "",
            goal: (goal || "").trim(),
            status: status,
            since: today(),
            lastCheckIn: 0,
            nextSession: 0,
            assignments: []
        }
        clients = clients.concat([client])
        return client.id
    }

    // An invited client accepted: they become an active client from today
    function activate(email) {
        const e = (email || "").trim().toLowerCase()
        const client = clients.find(c => c.email.toLowerCase() === e)
        if (!client)
            return
        _update(client.id, c => {
            c.status = "active"
            c.since = today()
        })
    }

    // The client stopped working with this coach
    function removeClient(email) {
        const e = (email || "").trim().toLowerCase()
        clients = clients.filter(c => c.email.toLowerCase() !== e)
    }

    // ---- internals ----------------------------------------------------------

    property int _lastId: 5000
    function _nextId() {
        _lastId += 1
        return _lastId
    }

    function _update(clientId, mutate) {
        const list = JSON.parse(JSON.stringify(clients))
        const client = list.find(c => c.id === clientId)
        if (!client)
            return
        mutate(client)
        clients = list
    }

    Component.onCompleted: {
        let nextAssignmentId = 1
        // Assignment that started `daysAgo` days ago
        const a = (programId, name, weeks, daysAgo, endedDaysAgo, reason, note) => ({
            id: nextAssignmentId++,
            programId: programId,
            programName: name,
            weeks: weeks,
            start: dayOffset(-daysAgo),
            note: note || "",
            endedAt: endedDaysAgo === undefined || endedDaysAgo === null ? 0 : dayOffset(-endedDaysAgo),
            endReason: reason || ""
        })
        const c = (id, name, email, phone, goal, status, sinceDaysAgo, checkInDaysAgo, nextSessionInDays, assignments) => ({
            id: id, name: name, email: email, phone: phone, goal: goal, status: status,
            since: dayOffset(-sinceDaysAgo),
            lastCheckIn: checkInDaysAgo === null ? 0 : dayOffset(-checkInDaysAgo),
            nextSession: nextSessionInDays === null ? 0 : dayOffset(nextSessionInDays),
            assignments: assignments
        })

        const strength = [101, "Strength foundations", 8]
        const home = [102, "Home training, no equipment", 6]
        const fatLoss = [103, "Fat loss conditioning", 12]

        clients = [
            c(1, "Luca Bianchi", "client@aura.app", "+39 333 120 4455", "Squat his bodyweight by the summer", "active", 160, 2, 2, [
                a(...home, 120, 78, "completed"),
                a(...strength, 33, null, "", "Focus on technique for the first two weeks.") ]),
            c(2, "Sara Conti", "sara.conti@example.com", "+39 347 882 1904", "Lose 6 kg and feel fitter", "active", 45, 1, 0, [
                a(...fatLoss, 20) ]),
            c(3, "Marco Ferri", "marco.ferri@example.com", "+39 320 554 7781", "Get back into the gym after an injury", "active", 90, 5, 0, [
                a(...home, 100, 58, "completed"),
                a(...strength, 60) ]),
            c(4, "Elena Greco", "elena.greco@example.com", "+39 351 220 9087", "Build a routine she can keep", "active", 3, null, 0, []),
            c(5, "Davide Russo", "davide.russo@example.com", "+39 339 671 2230", "Run a 10 km under 55 minutes", "active", 70, 16, null, [
                a(...home, 50) ]),
            c(6, "Chiara Moretti", "chiara.moretti@example.com", "+39 348 909 1123", "Tone up before her wedding", "active", 95, 3, 4, [
                a(...fatLoss, 81) ]),
            c(7, "Paolo Romano", "paolo.romano@example.com", "+39 366 404 5521", "General fitness, sits at a desk all day", "active", 1, null, 3, []),
            c(8, "Giorgia Marino", "giorgia.marino@example.com", "+39 340 777 3012", "Stay active while travelling for work", "active", 30, 4, 6, [
                a(...home, 10) ]),
            c(9, "Andrea Gallo", "andrea.gallo@example.com", "+39 329 118 6640", "First deadlift over 100 kg", "active", 12, 6, 5, [
                a(...strength, -5) ]),
            c(10, "Francesca Costa", "francesca.costa@example.com", "+39 335 290 8812", "Return after maternity leave", "paused", 300, 64, null, [
                a(...fatLoss, 150, 66, "ended") ]),
            c(11, "Matteo Fontana", "matteo.fontana@example.com", "+39 345 660 1279", "Improve posture and back pain", "active", 8, 1, 1, [
                a(...home, 2) ]),
            c(12, "Laura Ricci", "laura.ricci@example.com", "", "", "invited", 2, null, null, [])
        ]
    }
}
