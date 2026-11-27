import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One message: the user's own on the right in the brand color, the other
// person's on the left. Shows the time, with ticks on the user's own messages
// (MessageTicks), or "Not sent" with Retry and Delete.
Item {
    id: bubble

    property var message: ({ id: "", body: "", createdAt: 0, mine: false, status: "sent", receipt: "" })
    property real maxBubbleWidth: 520

    readonly property bool mine: message.mine
    readonly property bool failed: message.status === "failed"

    signal retryRequested()
    signal discardRequested()

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 3

        Rectangle {
            id: box

            readonly property real maxTextWidth: bubble.maxBubbleWidth - 24

            Layout.alignment: bubble.mine ? Qt.AlignRight : Qt.AlignLeft
            implicitWidth: Math.max(bodyLabel.width, meta.implicitWidth) + 24
            implicitHeight: bodyLabel.height + meta.implicitHeight + 16
            radius: 14
            color: bubble.mine ? (bubble.failed ? Theme.dangerSoft : Theme.primary) : Theme.surface
            border.width: bubble.mine && !bubble.failed ? 0 : 1
            border.color: bubble.failed ? Theme.danger : Theme.border
            opacity: bubble.message.status === "sending" ? 0.75 : 1

            Label {
                id: bodyLabel
                x: 12
                y: 8
                width: Math.min(implicitWidth, box.maxTextWidth)
                text: bubble.message.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: bubble.mine && !bubble.failed ? Theme.textOnPrimary : Theme.text
                font.pixelSize: Theme.fontBody
                lineHeight: 1.15
            }
            // Time and ticks
            Row {
                id: meta
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 10
                anchors.bottomMargin: 6
                spacing: 4

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bubble.failed ? qsTr("Not sent") : MessageStore.clockTime(bubble.message.createdAt)
                    color: bubble.failed ? Theme.danger
                         : bubble.mine ? Qt.alpha(Theme.textOnPrimary, 0.75)
                         : Theme.textMuted
                    font.pixelSize: Theme.fontSmall - 1
                }
                MessageTicks {
                    anchors.verticalCenter: parent.verticalCenter
                    receipt: bubble.failed ? "" : bubble.message.receipt
                    color: Qt.alpha(Theme.textOnPrimary, 0.75)
                    readColor: Theme.receiptReadOnPrimary
                }
            }
        }

        // Not sent: try again or throw away
        RowLayout {
            visible: bubble.failed
            spacing: 4
            Layout.alignment: Qt.AlignRight

            AuraButton {
                variant: "ghost"
                text: qsTr("Retry")
                onClicked: bubble.retryRequested()
            }
            AuraButton {
                variant: "ghost"
                text: qsTr("Delete")
                onClicked: bubble.discardRequested()
            }
        }
    }
}
