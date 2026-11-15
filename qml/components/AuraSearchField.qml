import QtQuick
import QtQuick.Controls.Basic

// Search input with a magnifier icon and a clear button.
TextField {
    id: field

    placeholderText: qsTr("Search…")
    implicitHeight: Theme.controlHeight
    implicitWidth: 280
    leftPadding: 40
    rightPadding: text.length > 0 ? 38 : 14
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.primary
    selectedTextColor: Theme.textOnPrimary
    font.pixelSize: Theme.fontBody
    selectByMouse: true
    inputMethodHints: Qt.ImhNoPredictiveText

    background: Rectangle {
        radius: Theme.radius
        color: Theme.surface
        border.width: field.activeFocus ? 2 : 1
        border.color: field.activeFocus ? Theme.primary : Theme.border
    }

    // Magnifier
    Item {
        x: 15
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16

        Rectangle {
            width: 11
            height: 11
            radius: 5.5
            color: "transparent"
            border.width: 2
            border.color: Theme.textMuted
        }
        Rectangle {
            x: 9
            y: 10
            width: 6
            height: 2
            radius: 1
            rotation: 45
            color: Theme.textMuted
        }
    }

    // Clear
    Rectangle {
        visible: field.text.length > 0
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 11
        color: clearArea.containsMouse ? Theme.border : Theme.surfaceAlt

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.textMuted
            font.pixelSize: 11
        }
        MouseArea {
            id: clearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                field.clear()
                field.forceActiveFocus()
            }
        }
    }
}
