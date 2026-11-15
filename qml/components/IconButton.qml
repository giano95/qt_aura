import QtQuick
import QtQuick.Controls.Basic

// Small square button showing a single glyph, with a tooltip.
AbstractButton {
    id: control

    property string glyph: ""
    property string tooltip: ""
    property bool destructive: false

    hoverEnabled: true
    implicitWidth: 32
    implicitHeight: 32
    focusPolicy: Qt.StrongFocus

    contentItem: Text {
        text: control.glyph
        font.pixelSize: 16
        color: !control.enabled ? Theme.border
             : control.destructive && control.hovered ? Theme.danger
             : control.hovered ? Theme.text
             : Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 8
        color: control.enabled && control.hovered
               ? (control.destructive ? Theme.dangerSoft : Theme.surfaceAlt)
               : "transparent"
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.primary
    }

    ToolTip.visible: hovered && tooltip.length > 0
    ToolTip.text: tooltip
    ToolTip.delay: 500

    HoverHandler {
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
