pragma Singleton
import QtQuick

// Fake content for the Phase 0 prototype screens.
// Replaced by data from the API in Phase 2.
QtObject {
    // ---- coach --------------------------------------------------------------

    readonly property var coachStats: [
        { label: qsTr("Active clients"), value: "12", note: qsTr("+2 this month"), tone: "primary" },
        { label: qsTr("Sessions today"), value: "4", note: qsTr("Next at 10:30"), tone: "neutral" },
        { label: qsTr("Check-ins to review"), value: "5", note: qsTr("2 overdue"), tone: "accent" },
        { label: qsTr("Unread messages"), value: "3", note: qsTr("From 2 clients"), tone: "neutral" }
    ]

    // status: done | next | upcoming
    readonly property var coachTodaySessions: [
        { time: "09:00", client: "Luca Bianchi", type: qsTr("Monthly review"), mode: qsTr("Video call"), status: "done" },
        { time: "10:30", client: "Sara Conti", type: qsTr("Goal setting"), mode: qsTr("In person"), status: "next" },
        { time: "14:00", client: "Marco Ferri", type: qsTr("Weekly check-in"), mode: qsTr("Video call"), status: "upcoming" },
        { time: "17:30", client: "Elena Greco", type: qsTr("First session"), mode: qsTr("In person"), status: "upcoming" }
    ]

    readonly property var coachAttention: [
        { client: "Davide Russo", reason: qsTr("Missed the last 2 check-ins"), tag: qsTr("Overdue"), tone: "danger" },
        { client: "Chiara Moretti", reason: qsTr("Program ends in 2 days"), tag: qsTr("Renew"), tone: "accent" },
        { client: "Paolo Romano", reason: qsTr("Submitted the onboarding form"), tag: qsTr("New"), tone: "primary" }
    ]

    // ---- client -------------------------------------------------------------

    readonly property string clientCoachName: "Giulia Rossi"

    readonly property var clientStats: [
        { label: qsTr("Sessions completed"), value: "14", note: qsTr("of 20 in your package"), tone: "neutral" },
        { label: qsTr("Check-in streak"), value: qsTr("6 weeks"), note: qsTr("Your best so far"), tone: "primary" },
        { label: qsTr("Current program"), value: qsTr("Week 5"), note: qsTr("of 8"), tone: "neutral" }
    ]

    // Two days from now at 18:00, so the prototype always shows a future date
    readonly property var clientNextSession: {
        const d = new Date()
        d.setDate(d.getDate() + 2)
        d.setHours(18, 0, 0, 0)
        return {
            date: d,
            duration: qsTr("60 min"),
            topic: qsTr("Monthly review and next steps"),
            mode: qsTr("Video call")
        }
    }

    readonly property var clientGoals: [
        { title: qsTr("Train 3 times a week"), progress: 0.75, note: qsTr("9 of 12 sessions this month") },
        { title: qsTr("Sleep 7+ hours a night"), progress: 0.5, note: qsTr("4 of the last 7 nights") },
        { title: qsTr("Finish the 8-week program"), progress: 0.6, note: qsTr("Week 5 of 8") }
    ]

    readonly property var clientLatestMessage: ({
        text: qsTr("Great work on the walks this week! Before Thursday, write down one thing that felt hard so we can look at it together."),
        time: qsTr("Yesterday, 19:42")
    })
}
