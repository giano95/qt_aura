import QtQuick

// Client app: navigation shell and its pages.
AppShell {
    id: shell

    roleLabel: qsTr("Client")
    // Tab order matters: pages navigate by index (see MyCoachPage / ClientDashboard)
    readonly property int coachTab: 1
    navItems: [qsTr("Home"), qsTr("My coach"), qsTr("Calendar"), qsTr("My program"), qsTr("Progress"), qsTr("Messages")]
    compactNavItems: [qsTr("Home"), qsTr("Coach"), qsTr("Calendar"), qsTr("Program"), qsTr("Progress"), qsTr("Messages")]
    messagesIndex: 5
    // Counts: unread messages (primary)
    navBadges: [
        [], [], [], [], [],
        [
            { count: MessageStore.unreadTotal, tone: "primary", label: qsTr("unread messages") }
        ]
    ]

    ClientDashboard {
        onNavigateRequested: index => shell.currentIndex = index
    }

    MyCoachPage {
        onNavigateRequested: index => shell.currentIndex = index
    }

    ClientCalendarPage {
        onNavigateRequested: index => shell.currentIndex = index
    }

    ClientProgramPage {}

    PlaceholderPage {
        title: qsTr("Progress")
        summary: qsTr("See how far you've come.")
        plannedFeatures: [
            qsTr("Goals with history charts"),
            qsTr("Weekly check-in answers over time"),
            qsTr("Milestones reached")
        ]
    }

    MessagesPage {
        coach: false
        onFindCoachRequested: shell.currentIndex = shell.coachTab
    }
}
