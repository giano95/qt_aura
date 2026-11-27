import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One conversation in the Messages list: who, the last message (with its ticks
// when it's the user's), when, and how many messages are unread.
AbstractButton {
    id: row

    property var conversation: ({ id: "", otherName: "", lastBody: "", lastAt: 0, lastMine: false, lastReceipt: "", unread: 0, open: true })
    property bool selected: false

    readonly property string preview: conversation.lastBody.replace(/\s+/g, " ")

    hoverEnabled: true
    padding: 12
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    Accessible.name: conversation.unread > 0
                     ? qsTr("%1, %n unread", "", conversation.unread).arg(conversation.otherName)
                     : conversation.otherName

    contentItem: RowLayout {
        spacing: 12

        Avatar {
            name: row.conversation.otherName
            size: 44
            opacity: row.conversation.open ? 1 : 0.6
        }

        ColumnLayout {
            spacing: 3
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Label {
                    text: row.conversation.otherName
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: MessageStore.listTime(row.conversation.lastAt)
                    color: row.conversation.unread > 0 ? Theme.primary : Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    font.weight: row.conversation.unread > 0 ? Font.DemiBold : Font.Normal
                }
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                MessageTicks {
                    receipt: row.conversation.lastReceipt
                    Layout.rightMargin: -4
                }
                Label {
                    text: row.preview.length === 0 ? qsTr("No messages yet")
                        : row.conversation.lastMine ? qsTr("You: %1").arg(row.preview)
                        : row.preview
                    color: row.conversation.unread > 0 ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.fontSmall + 1
                    font.italic: row.preview.length === 0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: row.conversation.unread > 0
                    implicitWidth: Math.max(20, unreadLabel.implicitWidth + 12)
                    implicitHeight: 20
                    radius: 10
                    color: Theme.primary

                    Label {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: row.conversation.unread > 99 ? "99+" : row.conversation.unread
                        color: Theme.textOnPrimary
                        font.pixelSize: Theme.fontSmall - 1
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: row.selected ? Theme.primarySoft
             : row.hovered ? Theme.surfaceAlt
             : "transparent"
        border.width: row.visualFocus ? 2 : 0
        border.color: Theme.primary
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
