pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// "Calendar" in the client app: your sessions (upcoming and past) and booking
// a new one in your coach's free time. New bookings are pending until the
// coach confirms them.
Item {
    id: page

    // Client app tab this page links to (see ClientHome)
    readonly property int coachTab: 1

    readonly property var coach: CoachStore.myCoach
    readonly property bool hasCoach: coach !== null && CoachStore.myRelation !== null && CoachStore.myRelation.status === "active"
    readonly property string firstName: coach ? coach.name.split(" ")[0] : ""
    readonly property var mySessions: Session.loggedIn ? CalendarStore.clientSessions(Session.user.email, Session.user.name, CalendarStore.revision) : []
    readonly property var upcoming: mySessions.filter(s => CalendarStore.endMs(s) > CalendarStore.now && s.status !== "cancelled")
    readonly property var past: mySessions.filter(s => CalendarStore.endMs(s) <= CalendarStore.now && s.status === "confirmed")
                                          .reverse().slice(0, 6)
    readonly property bool wide: scroll.availableWidth >= 900
    property string cancelId: ""

    signal navigateRequested(int index)

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        padding: width < 600 ? 16 : 32

        ColumnLayout {
            width: Math.min(scroll.availableWidth, 1200)
            x: (scroll.availableWidth - width) / 2
            spacing: 20

            PageHeader {
                Layout.fillWidth: true
                title: qsTr("Calendar")
                subtitle: page.hasCoach
                          ? qsTr("Book time with %1 and see your sessions. %1 confirms every request.").arg(page.firstName)
                          : qsTr("Your sessions with your coach.")
            }

            EmptyState {
                visible: !page.hasCoach
                Layout.fillWidth: true
                Layout.topMargin: 60
                title: qsTr("No coach yet")
                message: qsTr("Once you have a coach, you can book sessions in their free time here.")

                AuraButton {
                    text: qsTr("Find a coach")
                    onClicked: page.navigateRequested(page.coachTab)
                }
            }

            // ---- book: the coach's week ----
            ClientBookingCalendar {
                visible: page.hasCoach
                Layout.fillWidth: true
                coachId: page.coach ? page.coach.id : ""
                wide: page.wide
                onRequestRequested: (dayMs, start, end) => bookDialog.openFor(page.coach.id, dayMs, start, end)
            }

            // ---- your sessions ----
            GridLayout {
                visible: page.hasCoach
                Layout.fillWidth: true
                Layout.topMargin: 8
                columns: page.wide ? 2 : 1
                columnSpacing: 24
                rowSpacing: 24

                ColumnLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop

                    Label {
                        text: qsTr("Upcoming")
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: page.upcoming
                        ClientSessionCard {
                            required property var modelData
                            Layout.fillWidth: true
                            session: modelData
                            canCancel: CalendarStore.canClientCancel(modelData, CalendarStore.revision)
                            tooLateToCancel: CalendarStore.isActive(modelData) && !CalendarStore.canClientCancel(modelData, CalendarStore.revision)
                            onCancelRequested: {
                                page.cancelId = modelData.id
                                cancelDialog.open()
                            }
                        }
                    }

                    Label {
                        visible: page.upcoming.length === 0
                        text: qsTr("No sessions booked. Choose a free time above.")
                        color: Theme.textMuted
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop

                    Label {
                        text: qsTr("Past sessions")
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: page.past
                        ClientSessionCard {
                            required property var modelData
                            Layout.fillWidth: true
                            session: modelData
                            compact: true
                        }
                    }

                    Label {
                        visible: page.past.length === 0
                        text: qsTr("No past sessions yet.")
                        color: Theme.textMuted
                    }
                }
            }

            Item { implicitHeight: 16 }
        }
    }

    Toast {
        id: toast
    }

    BookSessionDialog {
        id: bookDialog
        onSent: toast.show(qsTr("Request sent to %1").arg(page.firstName))
    }

    ConfirmDialog {
        id: cancelDialog
        readonly property var session: CalendarStore.sessionById(page.cancelId, CalendarStore.revision)
        title: session && session.status === "pending" ? qsTr("Cancel your request?") : qsTr("Cancel this session?")
        message: session
                 ? qsTr("%1, %2–%3 with %4. The time will be free again.")
                       .arg(Qt.formatDate(new Date(CalendarStore.startMs(session)), "dddd d MMMM"))
                       .arg(CalendarStore.formatMinutes(session.start)).arg(CalendarStore.formatMinutes(session.end))
                       .arg(page.coach ? page.coach.name : "")
                 : ""
        cancelText: qsTr("Keep it")
        confirmText: qsTr("Cancel session")
        destructive: true
        onConfirmed: {
            CalendarStore.cancelSession(page.cancelId, "client")
            toast.show(qsTr("Session cancelled"))
        }
    }
}
