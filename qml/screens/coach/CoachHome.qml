import QtQuick

// Coach app: navigation shell and its pages.
AppShell {
    id: shell

    // Tab order matters: pages navigate by index (see CoachDashboard)
    readonly property int clientsTab: 1
    readonly property int programsTab: 3

    roleLabel: qsTr("Coach")
    messagesIndex: 5
    navItems: [qsTr("Dashboard"), qsTr("Clients"), qsTr("Calendar"), qsTr("Programs"), qsTr("Exercises"), qsTr("Messages")]
    compactNavItems: [qsTr("Home"), qsTr("Clients"), qsTr("Calendar"), qsTr("Programs"), qsTr("Exercises"), qsTr("Messages")]
    // Counts: requests waiting for an answer (primary), expired programs (red),
    // unread messages (primary)
    navBadges: [
        [],
        [
            { count: CoachStore.pendingRequests.length, tone: "primary", label: qsTr("new requests") },
            { count: ClientStore.count("expired", ClientStore.revision), tone: "danger", label: qsTr("expired programs") }
        ],
        [
            { count: CalendarStore.pendingBookings.length, tone: "primary", label: qsTr("booking requests") }
        ],
        [], [],
        [
            { count: MessageStore.unreadTotal, tone: "primary", label: qsTr("unread messages") }
        ]
    ]

    CoachDashboard {
        onNavigateRequested: index => shell.currentIndex = index
    }

    ClientsSection {
        onMessageRequested: coachingId => {
            MessageStore.open(coachingId)
            shell.currentIndex = shell.messagesIndex
        }
        onOpenProgramRequested: (programId, clientName) => {
            programsSection.openProgram(programId, clientName ? "← " + clientName : qsTr("← Back"))
            shell.currentIndex = shell.programsTab
        }
    }

    CalendarPage {}

    ProgramsSection {
        id: programsSection
        onReturnRequested: shell.currentIndex = shell.clientsTab
    }

    ExercisesPage {}

    MessagesPage {
        coach: true
    }
}
