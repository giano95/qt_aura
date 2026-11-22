import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Calendar area of the coach app: the week view, where single slots are
// blocked, and a header button to edit the standard weekly working hours.
Item {
    id: page

    readonly property bool wide: scroll.availableWidth >= 760

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        padding: width < 600 ? 16 : 32

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 20

            PageHeader {
                Layout.fillWidth: true
                title: qsTr("Calendar")
                subtitle: qsTr("Your sessions and free time. Block single slots when you're not available.")

                AuraButton {
                    visible: CalendarStore.pendingBookings.length > 0
                    text: qsTr("Booking requests · %1").arg(CalendarStore.pendingBookings.length)
                    onClicked: bookingsDialog.openAll()
                }
                AuraButton {
                    variant: CalendarStore.pendingBookings.length > 0 ? "secondary" : "primary"
                    text: qsTr("Edit working hours")
                    onClicked: hoursDialog.openEditor()
                }
            }

            WeekCalendar {
                id: weekCalendar
                wide: page.wide
                Layout.fillWidth: true
                // Any session (request, confirmed or past): open its details
                onSessionClicked: sessionId => bookingsDialog.openFor(sessionId)
            }
        }
    }

    ConfirmDialog {
        id: cancelSessionDialog

        property string sessionId: ""
        readonly property var session: CalendarStore.sessionById(sessionId, CalendarStore.revision)

        function ask(id) {
            sessionId = id
            open()
        }

        title: qsTr("Cancel this session?")
        message: session
                 ? qsTr("%1, %2–%3 with %4. %4 will see it as cancelled by you.")
                       .arg(Qt.formatDate(new Date(CalendarStore.startMs(session)), "dddd d MMMM"))
                       .arg(CalendarStore.formatMinutes(session.start)).arg(CalendarStore.formatMinutes(session.end))
                       .arg(session.client)
                 : ""
        cancelText: qsTr("Keep it")
        confirmText: qsTr("Cancel session")
        destructive: true
        onConfirmed: {
            CalendarStore.cancelSession(sessionId, "coach")
            toast.show(qsTr("Session cancelled"))
        }
    }

    BookingRequestsDialog {
        id: bookingsDialog
        onCancelRequested: sessionId => cancelSessionDialog.ask(sessionId)
        onSessionConfirmed: name => toast.show(qsTr("Session with %1 confirmed").arg(name))
        onSessionDeclined: name => toast.show(qsTr("Session with %1 declined").arg(name))
    }

    WorkingHoursDialog {
        id: hoursDialog
        onSaved: toast.show(qsTr("Working hours saved"))
    }

    Toast {
        id: toast
    }
}
