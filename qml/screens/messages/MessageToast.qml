import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Pop-up for a message that arrived while its chat isn't on screen: who sent
// it and the start of the text. Click it to open the chat. Hides after a few
// seconds (not while the pointer is on it).
AbstractButton {
    id: toast

    property string conversationId: ""
    property string senderName: ""
    property string body: ""

    signal openRequested(string conversationId)

    function show(id, name, text) {
        conversationId = id
        senderName = name
        body = text.replace(/\s+/g, " ")
        opacity = 1
        hideTimer.restart()
    }

    z: 200
    width: Math.min(360, parent ? parent.width - 32 : 360)
    padding: 12
    hoverEnabled: true
    opacity: 0
    visible: opacity > 0
    onClicked: {
        opacity = 0
        openRequested(conversationId)
    }

    Accessible.name: qsTr("New message from %1: %2").arg(senderName).arg(body)

    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    contentItem: RowLayout {
        spacing: 12

        Avatar {
            name: toast.senderName
            size: 36
            Layout.alignment: Qt.AlignTop
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            Label {
                text: toast.senderName
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                text: toast.body
                color: Theme.textMuted
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: toast.hovered ? Theme.surfaceAlt : Theme.surface
        border.width: 1
        border.color: Theme.primary
    }

    Timer {
        id: hideTimer
        interval: 5000
        running: false
        onTriggered: {
            if (toast.hovered)
                restart()
            else
                toast.opacity = 0
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
