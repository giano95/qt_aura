import QtQuick
import QtQuick.Controls.Basic

// On/off switch. Bind `checked`, react to `toggled()`.
AbstractButton {
    id: control

    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: 42
    implicitHeight: 24

    contentItem: Item {}

    background: Rectangle {
        radius: height / 2
        color: control.checked ? Theme.primary : Theme.border
        opacity: control.enabled ? 1 : 0.5
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.primaryHover

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            color: "#FFFFFF"

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
