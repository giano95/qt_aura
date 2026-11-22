pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// openAll(): every session clients asked for, waiting for an answer.
// openFor(id): one session (request or confirmed) with what can be done with it.
AuraDialog {
    id: dialog

    property string onlyId: ""        // "" = all pending requests

    readonly property var requests: onlyId !== ""
                                    ? [CalendarStore.sessionById(onlyId, CalendarStore.revision)].filter(s => s !== null)
                                    : CalendarStore.pendingBookings

    signal sessionConfirmed(string clientName)
    signal sessionDeclined(string clientName)
    signal cancelRequested(string sessionId)

    function openAll() {
        onlyId = ""
        open()
    }

    function openFor(id) {
        onlyId = id
        open()
    }

    function whenText(session) {
        return Qt.formatDate(new Date(CalendarStore.startMs(session)), "dddd d MMMM") + " · "
             + CalendarStore.formatMinutes(session.start) + "–" + CalendarStore.formatMinutes(session.end)
    }

    title: onlyId === "" ? qsTr("Booking requests")
         : requests.length > 0 && requests[0].status === "pending" ? qsTr("Session request")
         : qsTr("Session")
    preferredWidth: 620


    Label {
        visible: dialog.onlyId === "" && dialog.requests.length > 0
        text: qsTr("Sessions your clients booked in your free slots. They're held for them until you answer.")
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    EmptyState {
        visible: dialog.requests.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        title: qsTr("No booking requests")
        message: qsTr("When a client books one of your free slots, it shows up here.")
    }

    Repeater {
        model: dialog.requests

        Rectangle {
            id: request
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: requestColumn.implicitHeight + 32
            radius: Theme.radiusLarge
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: requestColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    Avatar {
                        name: request.modelData.client
                        size: 44
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Label {
                            text: request.modelData.client
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: dialog.whenText(request.modelData) + " · "
                                  + CalendarStore.durationText(request.modelData.end - request.modelData.start)
                            color: Theme.primary
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: request.modelData.type + " · " + request.modelData.mode
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignTop

                        Chip {
                            visible: request.modelData.status !== "pending"
                            text: request.modelData.status === "confirmed" ? qsTr("Confirmed") : CalendarStore.statusText(request.modelData)
                            tone: CalendarStore.statusTone(request.modelData)
                            Layout.alignment: Qt.AlignRight
                        }
                        Label {
                            visible: request.modelData.requestedAt > 0
                            text: qsTr("Asked %1").arg(ClientStore.relativeDay(request.modelData.requestedAt).toLowerCase())
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }

                Label {
                    visible: request.modelData.note.length > 0
                    text: "“" + request.modelData.note + "”"
                    font.italic: true
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Confirmed and still to come: the coach can cancel it
                RowLayout {
                    visible: request.modelData.status === "confirmed" && CalendarStore.endMs(request.modelData) > CalendarStore.now
                    spacing: 8
                    Layout.alignment: Qt.AlignRight

                    AuraButton {
                        variant: "ghostDanger"
                        text: qsTr("Cancel session")
                        onClicked: {
                            dialog.close()
                            dialog.cancelRequested(request.modelData.id)
                        }
                    }
                }

                RowLayout {
                    visible: request.modelData.status === "pending"
                    spacing: 8
                    Layout.alignment: Qt.AlignRight

                    AuraButton {
                        variant: "ghostDanger"
                        text: qsTr("Decline")
                        onClicked: {
                            const name = request.modelData.client
                            CalendarStore.declineSession(request.modelData.id)
                            dialog.sessionDeclined(name)
                            if (dialog.onlyId !== "")
                                dialog.close()
                        }
                    }
                    AuraButton {
                        text: qsTr("Confirm session")
                        onClicked: {
                            const name = request.modelData.client
                            CalendarStore.confirmSession(request.modelData.id)
                            dialog.sessionConfirmed(name)
                            if (dialog.onlyId !== "")
                                dialog.close()
                        }
                    }
                }
            }
        }
    }

    actions: AuraButton {
        variant: "secondary"
        text: qsTr("Close")
        onClicked: dialog.close()
    }
}
