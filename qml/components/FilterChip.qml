import QtQuick
import QtQuick.Controls.Basic

// Selectable pill, used for filters and single-choice pickers.
AbstractButton {
    id: control

    property bool selected: false
    property string count: ""        // optional number shown after the text
    property bool marked: false      // small dot in the corner, e.g. "has changes"

    hoverEnabled: true
    implicitHeight: 32
    implicitWidth: label.implicitWidth + 28
    focusPolicy: Qt.StrongFocus

    contentItem: Label {
        id: label
        text: control.count.length > 0 ? control.text + "  " + control.count : control.text
        font.pixelSize: Theme.fontSmall + 1
        font.weight: control.selected ? Font.DemiBold : Font.Medium
        color: control.selected ? Theme.textOnPrimary : Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: height / 2
        color: control.selected ? Theme.primary
             : control.hovered ? Theme.surfaceAlt
             : Theme.surface
        border.width: control.selected ? 0 : 1
        border.color: control.visualFocus ? Theme.primary : Theme.border
    }

    Rectangle {
        visible: control.marked
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -2
        anchors.rightMargin: -2
        width: 10
        height: 10
        radius: 5
        color: Theme.accent
        border.width: 2
        border.color: Theme.background
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
