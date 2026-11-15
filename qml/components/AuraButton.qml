import QtQuick
import QtQuick.Controls.Basic

// Standard button. variant: "primary" | "secondary" | "ghost" | "danger" | "ghostDanger"
Button {
    id: control

    property string variant: "primary"
    property bool busy: false
    property string busyText: qsTr("Please wait…")

    enabled: !busy
    hoverEnabled: true
    implicitHeight: Theme.controlHeight
    leftPadding: 18
    rightPadding: 18
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold

    contentItem: Text {
        text: control.busy ? control.busyText : control.text
        font: control.font
        color: control.variant === "primary" ? Theme.textOnPrimary
             : control.variant === "danger" ? (Theme.dark ? "#2A0906" : "#FFFFFF")
             : control.variant === "ghost" ? Theme.primary
             : control.variant === "ghostDanger" ? Theme.danger
             : Theme.text
        opacity: control.enabled || control.busy ? 1 : 0.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radius
        opacity: control.enabled || control.busy ? 1 : 0.5
        color: {
            const active = control.hovered || control.down
            if (control.variant === "primary")
                return active ? Theme.primaryHover : Theme.primary
            if (control.variant === "danger")
                return active ? Qt.darker(Theme.danger, 1.1) : Theme.danger
            if (control.variant === "secondary")
                return active ? Theme.surfaceAlt : Theme.surface
            if (control.variant === "ghostDanger")
                return active ? Theme.dangerSoft : "transparent"
            return active ? Theme.surfaceAlt : "transparent"
        }
        border.width: control.variant === "secondary" ? 1 : 0
        border.color: Theme.border

        // Keyboard focus ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            opacity: 0.5
            visible: control.visualFocus
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
