import QtQuick
import QtQuick.Controls.Basic

// Styled popup menu. Add Action children; set objectName: "destructive" on an
// Action to show it in red.
Menu {
    id: menu

    padding: 6

    background: Rectangle {
        implicitWidth: 200
        color: Theme.surface
        radius: Theme.radius
        border.width: 1
        border.color: Theme.border
    }

    delegate: MenuItem {
        id: item

        readonly property bool destructive: action !== null && action.objectName === "destructive"

        implicitHeight: 36
        leftPadding: 12
        rightPadding: 12

        contentItem: Text {
            text: item.text
            font.pixelSize: Theme.fontBody
            color: !item.enabled ? Theme.border
                 : item.destructive ? Theme.danger
                 : Theme.text
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: item.highlighted && item.enabled
                   ? (item.destructive ? Theme.dangerSoft : Theme.surfaceAlt)
                   : "transparent"
        }
    }
}
