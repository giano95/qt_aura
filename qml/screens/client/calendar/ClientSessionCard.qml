import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One of the client's sessions: date, time, type, status, and a cancel button
// for upcoming ones.
Rectangle {
    id: card

    property var session: ({ dateKey: "2000-01-01", start: 0, end: 60, type: "", mode: "", status: "confirmed", note: "" })
    property bool canCancel: false
    property bool tooLateToCancel: false     // upcoming, but less than 24 h away
    property bool compact: false          // past sessions: smaller, no note

    readonly property var date: new Date(CalendarStore.startMs(session))
    readonly property bool muted: session.status === "declined" || session.status === "cancelled"

    signal cancelRequested()

    implicitHeight: row.implicitHeight + (compact ? 20 : 28)
    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: session.status === "pending" ? 1.5 : 1
    border.color: session.status === "pending" ? Theme.accent : Theme.border
    opacity: muted ? 0.75 : 1

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        Rectangle {
            implicitWidth: card.compact ? 44 : 56
            implicitHeight: card.compact ? 48 : 60
            radius: 10
            color: card.session.status === "pending" ? Theme.accentSoft : card.muted ? Theme.surfaceAlt : Theme.primarySoft

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Label {
                    text: Qt.formatDate(card.date, "MMM").toUpperCase()
                    color: card.session.status === "pending" ? Theme.accent : card.muted ? Theme.textMuted : Theme.primary
                    font.pixelSize: Theme.fontSmall - 1
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: card.date.getDate()
                    color: card.session.status === "pending" ? Theme.accent : card.muted ? Theme.textMuted : Theme.primary
                    font.pixelSize: card.compact ? 18 : 22
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        ColumnLayout {
            spacing: 3
            Layout.fillWidth: true

            Label {
                text: Qt.formatDate(card.date, "dddd") + " · "
                      + CalendarStore.formatMinutes(card.session.start) + "–" + CalendarStore.formatMinutes(card.session.end)
                      + " · " + CalendarStore.durationText(card.session.end - card.session.start)
                font.weight: Font.DemiBold
                font.strikeout: card.session.status === "cancelled"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                text: card.session.type + " · " + card.session.mode
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: !card.compact && card.session.note.length > 0
                text: "“" + card.session.note + "”"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.italic: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Chip {
                visible: !card.compact
                text: CalendarStore.statusText(card.session)
                tone: CalendarStore.statusTone(card.session)
                Layout.topMargin: 2
            }
        }

        Label {
            visible: card.tooLateToCancel
            text: qsTr("Can't cancel\nless than %1 h before").arg(CalendarStore.cancelNoticeHours)
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall - 1
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignTop
        }

        AuraButton {
            visible: card.canCancel
            variant: "ghostDanger"
            text: qsTr("Cancel")
            implicitHeight: 34
            leftPadding: 10
            rightPadding: 10
            Layout.alignment: Qt.AlignTop
            onClicked: card.cancelRequested()
        }
    }
}
