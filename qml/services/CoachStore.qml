pragma Singleton
import QtQuick

// Coach directory and the link between a client and their coach.
//
// PHASE 0: in-memory mock. In Phase 2: tables coaches (public profile) and
// coach_client_links (client, coach, status, dates), plus an endpoint for
// coaches to accept or decline requests.
//
// Data shapes
//   coach:    { id, name, title, city, online, inPerson, studio, specialties[],
//               bio, years, certifications[], languages[], priceFrom (EUR per session),
//               accepting, visibility: "public" | "private", email, phone,
//               weeklyHours (CalendarStore shape) }
//   relation: { coachId, status, since (ms), name, goal, message }
//             status: "none" | "invited" | "pending" | "declined" | "active"
//
// How clients and coaches get together:
//   - public coaches are listed in the directory; clients send a request and
//     the coach accepts or declines it
//   - private coaches aren't listed; they invite clients by email and the
//     client accepts or declines the invitation
//
// Coach 1 (Giulia Rossi) is the demo coach account. Her clients and invitations
// are the ones in ClientStore (the source of truth for her), her working hours
// are in CalendarStore, and requests to her wait for her to answer them in the
// coach app. The other coaches have no account behind them, so in the
// prototype they accept requests automatically.
QtObject {
    id: store

    readonly property int demoCoachId: 1
    // Prototype only: a coach accepts a request this long after it is sent
    readonly property int autoAcceptMs: 4000

    property var coaches: []
    // Requests and links that aren't in ClientStore, by client email
    property var relations: ({})

    // The logged-in client's link and coach (null for coach accounts)
    readonly property var myRelation: Session.loggedIn && !Session.isCoach ? relationFor(Session.user.email) : null
    readonly property var myCoach: myRelation && myRelation.status !== "none" ? coachById(myRelation.coachId) : null

    // The demo coach's profile visibility and the requests waiting for her
    readonly property var demoCoach: coachById(demoCoachId)
    readonly property bool demoIsPublic: demoCoach !== null && demoCoach.visibility === "public"
    readonly property var pendingRequests: Object.keys(relations)
        .filter(e => relations[e].coachId === demoCoachId && relations[e].status === "pending")
        .map(e => Object.assign({ email: e }, relations[e]))
        .sort((a, b) => b.since - a.since)

    signal requestAccepted(string coachName)

    // ---- reading ------------------------------------------------------------

    function coachById(id) {
        return coaches.find(c => c.id === id) || null
    }

    function relationFor(email) {
        const e = (email || "").trim().toLowerCase()
        const client = ClientStore.clientByEmail(e)
        if (client)
            return {
                coachId: demoCoachId,
                status: client.status === "invited" ? "invited" : "active",
                since: client.since, name: client.name, goal: client.goal, message: ""
            }
        return relations[e] || _none()
    }

    // mode: "all" | "online" | "inPerson"
    function search(query, mode) {
        const q = (query || "").trim().toLowerCase()
        return coaches
            .filter(c => c.visibility === "public")
            .filter(c => mode === "online" ? c.online : mode === "inPerson" ? c.inPerson : true)
            .filter(c => !q
                || c.name.toLowerCase().includes(q)
                || c.title.toLowerCase().includes(q)
                || c.city.toLowerCase().includes(q)
                || c.specialties.some(s => s.toLowerCase().includes(q)))
            .sort((a, b) => (b.accepting - a.accepting) || a.name.localeCompare(b.name))
    }

    function weeklyHoursOf(coach) {
        return coach.id === demoCoachId ? CalendarStore.weeklyHours : coach.weeklyHours
    }

    // "Mon–Fri 09:00–18:00", "Sat 09:00–13:00", ... (consecutive days with the
    // same hours grouped)
    function hoursSummary(coach) {
        const hours = weeklyHoursOf(coach)
        const order = [1, 2, 3, 4, 5, 6, 0]
        const short = d => Qt.locale().dayName(d, Locale.ShortFormat)
        const text = d => (hours[String(d)] || [])
            .map(r => CalendarStore.formatMinutes(r.start) + "–" + (r.end >= 1440 ? "24:00" : CalendarStore.formatMinutes(r.end)))
            .join(", ")
        const lines = []
        let i = 0
        while (i < order.length) {
            const t = text(order[i])
            let j = i
            while (j + 1 < order.length && text(order[j + 1]) === t)
                ++j
            if (t)
                lines.push((i === j ? short(order[i]) : short(order[i]) + "–" + short(order[j])) + " " + t)
            i = j + 1
        }
        return lines.length > 0 ? lines : [qsTr("No regular hours set")]
    }

    function modesText(coach) {
        if (coach.online && coach.inPerson)
            return qsTr("Online and in person")
        return coach.online ? qsTr("Online only") : qsTr("In person only")
    }

    // ---- changes (for the logged-in client) ---------------------------------

    // Sends a request to a public coach
    function request(coachId, goal, message) {
        if (!Session.loggedIn)
            return
        const email = Session.user.email.toLowerCase()
        _setRelation(email, {
            coachId: coachId,
            status: "pending",
            since: Date.now(),
            name: Session.user.name,
            goal: (goal || "").trim(),
            message: (message || "").trim()
        })
        // The demo coach answers in the coach app; the others answer by themselves
        if (coachId !== demoCoachId) {
            _pendingEmail = email
            _acceptTimer.restart()
        }
    }

    function cancelRequest() {
        _acceptTimer.stop()
        if (Session.loggedIn)
            _removeRelation(Session.user.email.toLowerCase())
    }

    // After a decline, back to choosing a coach
    function dismissDeclined() {
        if (Session.loggedIn)
            _removeRelation(Session.user.email.toLowerCase())
    }

    // An invitation from the demo coach (private profile)
    function acceptInvitation() {
        if (Session.loggedIn)
            ClientStore.activate(Session.user.email)
    }

    function declineInvitation() {
        if (Session.loggedIn)
            ClientStore.removeClient(Session.user.email)
    }

    // Ends the coaching relationship. With the demo coach, the client also
    // leaves her client list (and with it their program).
    function leave() {
        if (!Session.loggedIn)
            return
        const email = Session.user.email.toLowerCase()
        if (relationFor(email).coachId === demoCoachId)
            ClientStore.removeClient(email)
        _removeRelation(email)
    }

    // ---- changes (for the demo coach) ---------------------------------------

    function acceptRequest(email) {
        const r = relations[email]
        if (!r || r.status !== "pending")
            return
        _removeRelation(email)
        ClientStore.addClient(r.name || email, email, r.goal, "active")
    }

    function declineRequest(email) {
        const r = relations[email]
        if (r && r.status === "pending")
            _setRelation(email, Object.assign({}, r, { status: "declined" }))
    }

    // Going private takes the coach out of the directory and declines the
    // requests still waiting
    function setDemoVisibility(visibility) {
        coaches = coaches.map(c => c.id === demoCoachId ? Object.assign({}, c, { visibility: visibility }) : c)
        if (visibility === "private")
            pendingRequests.forEach(r => declineRequest(r.email))
    }

    // ---- internals ----------------------------------------------------------

    property string _pendingEmail: ""
    property Timer _acceptTimer: Timer {
        interval: store.autoAcceptMs
        onTriggered: store._accept(store._pendingEmail)
    }

    function _none() {
        return { coachId: 0, status: "none", since: 0, name: "", goal: "", message: "" }
    }

    function _setRelation(email, relation) {
        const next = Object.assign({}, relations)
        next[email] = relation
        relations = next
    }

    function _removeRelation(email) {
        const next = Object.assign({}, relations)
        delete next[email]
        relations = next
    }

    // Prototype: a coach without an account accepts by themselves
    function _accept(email) {
        const relation = relations[email]
        if (!relation || relation.status !== "pending" || relation.coachId === demoCoachId)
            return
        _setRelation(email, Object.assign({}, relation, { status: "active", since: Date.now() }))
        const coach = coachById(relation.coachId)
        requestAccepted(coach ? coach.name : "")
    }

    Component.onCompleted: {
        // Two people waiting for the demo coach to answer
        const hoursAgo = h => Date.now() - h * 3600000
        relations = {
            "federico.russo@example.com": {
                coachId: 1, status: "pending", since: hoursAgo(3), name: "Federico Russo",
                goal: "Get back in shape after two years off",
                message: "I used to play football. Free on weekday evenings."
            },
            "martina.esposito@example.com": {
                coachId: 1, status: "pending", since: hoursAgo(26), name: "Martina Esposito",
                goal: "Prepare for a hiking trip in the Dolomites",
                message: ""
            }
        }

        const weekdays = (start, end) => ({
            "1": [{ start: start, end: end }], "2": [{ start: start, end: end }], "3": [{ start: start, end: end }],
            "4": [{ start: start, end: end }], "5": [{ start: start, end: end }], "6": [], "0": []
        })

        coaches = [
            {
                id: 1, name: "Giulia Rossi", title: qsTr("Strength & conditioning coach"),
                city: "Milano", online: true, inPerson: true, studio: "Studio Aura · Via Tortona 27, Milano",
                specialties: ["Strength", "Weight loss", "Habits"],
                bio: "I help busy people get strong without living in the gym. Three focused sessions a week, a plan that adapts to your life, and weekly check-ins so you never feel on your own.",
                years: 9, certifications: ["NSCA-CSCS", "Precision Nutrition Level 1"], languages: ["Italian", "English"],
                priceFrom: 55, accepting: true, visibility: "public", email: "coach@aura.app", phone: "+39 02 1234 5678",
                weeklyHours: {}
            },
            {
                id: 2, name: "Marco Bellini", title: qsTr("Running & endurance coach"),
                city: "Torino", online: true, inPerson: true, studio: "Parco del Valentino, Torino",
                specialties: ["Running", "Endurance", "Injury prevention"],
                bio: "From your first 5 km to your first marathon. Training plans built around your schedule, with strength work to keep you injury-free.",
                years: 7, certifications: ["FIDAL Level 2 coach"], languages: ["Italian", "English"],
                priceFrom: 45, accepting: true, visibility: "public", email: "marco.bellini@example.com", phone: "+39 011 555 0101",
                weeklyHours: Object.assign(weekdays(7 * 60, 13 * 60), { "6": [{ start: 8 * 60, end: 12 * 60 }] })
            },
            {
                id: 3, name: "Sofia Ricci", title: qsTr("Nutrition & weight-loss coach"),
                city: "Roma", online: true, inPerson: false, studio: "",
                specialties: ["Weight loss", "Nutrition", "Habits"],
                bio: "No crash diets. We build eating habits you can keep, one small change a week, with training that fits around them.",
                years: 5, certifications: ["Registered dietitian"], languages: ["Italian"],
                priceFrom: 35, accepting: true, visibility: "public", email: "sofia.ricci@example.com", phone: "",
                weeklyHours: weekdays(10 * 60, 19 * 60)
            },
            {
                id: 4, name: "Alessandro Neri", title: qsTr("Powerlifting coach"),
                city: "Milano", online: false, inPerson: true, studio: "Iron Lab · Viale Monza 120, Milano",
                specialties: ["Strength", "Powerlifting", "Technique"],
                bio: "Competitive powerlifter and coach. If you want a bigger squat, bench and deadlift, with technique that holds under heavy weight, let's talk.",
                years: 12, certifications: ["FIPL coach", "NSCA-CSCS"], languages: ["Italian", "English"],
                priceFrom: 60, accepting: false, visibility: "public", email: "alessandro.neri@example.com", phone: "+39 02 555 0199",
                weeklyHours: weekdays(15 * 60, 21 * 60)
            },
            {
                id: 5, name: "Chiara Lombardi", title: qsTr("Mobility & pre/postnatal coach"),
                city: "Bologna", online: true, inPerson: true, studio: "Spazio Movimento · Via Saragozza 40, Bologna",
                specialties: ["Mobility", "Pre & postnatal", "Pilates"],
                bio: "Gentle, progressive training for every stage of life: pregnancy, return to exercise after birth, or simply moving without pain.",
                years: 10, certifications: ["Pilates instructor", "Pre/postnatal specialist"], languages: ["Italian", "English", "Spanish"],
                priceFrom: 50, accepting: true, visibility: "public", email: "chiara.lombardi@example.com", phone: "+39 051 555 0177",
                weeklyHours: weekdays(9 * 60, 17 * 60)
            },
            {
                id: 6, name: "Tommaso Galli", title: qsTr("Calisthenics coach"),
                city: "Firenze", online: true, inPerson: false, studio: "",
                specialties: ["Bodyweight", "Calisthenics", "Mobility"],
                bio: "Your first pull-up, a solid handstand, or just a strong body with no equipment. All training is online, with video feedback on your form.",
                years: 4, certifications: ["Calisthenics instructor"], languages: ["Italian", "English"],
                priceFrom: 30, accepting: true, visibility: "public", email: "tommaso.galli@example.com", phone: "",
                weeklyHours: Object.assign(weekdays(17 * 60, 21 * 60), { "6": [{ start: 9 * 60, end: 13 * 60 }] })
            }
        ]
    }
}
