import QtQuick

// Coach app: navigation shell and its pages.
AppShell {
    id: shell

    roleLabel: qsTr("Coach")
    navItems: [qsTr("Dashboard"), qsTr("Clients"), qsTr("Calendar"), qsTr("Programs"), qsTr("Exercises"), qsTr("Messages")]
    compactNavItems: [qsTr("Home"), qsTr("Clients"), qsTr("Calendar"), qsTr("Programs"), qsTr("Exercises"), qsTr("Messages")]
    // Counts: requests waiting for an answer (primary), expired programs (red)
    navBadges: [
        [],
        [
            { count: CoachStore.pendingRequests.length, tone: "primary", label: qsTr("new requests") },
            { count: ClientStore.count("expired"), tone: "danger", label: qsTr("expired programs") }
        ],
        [
            { count: CalendarStore.pendingBookings.length, tone: "primary", label: qsTr("booking requests") }
        ],
        [], [], []
    ]

    CoachDashboard {
        onNavigateRequested: index => shell.currentIndex = index
    }

    ClientsSection {
        onOpenProgramRequested: (programId, clientName) => {
            programsSection.openProgram(programId, clientName ? "← " + clientName : qsTr("← Back"))
            shell.currentIndex = 3
        }
    }

    CalendarPage {}

    ProgramsSection {
        id: programsSection
        onReturnRequested: shell.currentIndex = 1
    }

    ExercisesPage {}

    PlaceholderPage {
        title: qsTr("Messages")
        summary: qsTr("One conversation per client, plus their check-in answers.")
        plannedFeatures: [
            qsTr("Message thread per client"),
            qsTr("Weekly check-in forms and answers"),
            qsTr("Unread badges and notifications")
        ]
    }
}
