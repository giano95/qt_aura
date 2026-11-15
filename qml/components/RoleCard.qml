import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Large tappable card for picking an account type.
// showArrow: true  -> navigation style (welcome screen)
// showArrow: false -> radio selection style (signup form)
AbstractButton {
    id: control

    property string title: ""
    property string description: ""
    property bool selected: false
    property bool showArrow: false

    hoverEnabled: true
    padding: 16
    implicitWidth: 300
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: RowLayout {
        spacing: 14

        Rectangle {
            visible: !control.showArrow
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            implicitWidth: 20
            implicitHeight: 20
            radius: 10
            color: "transparent"
            border.width: control.selected ? 6 : 2
            border.color: control.selected ? Theme.primary : Theme.border
        }

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            Label {
                text: control.title
                font.pixelSize: Theme.fontLarge
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Label {
                text: control.description
                color: Theme.textMuted
                font.pixelSize: Theme.fontBody
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        Label {
            visible: control.showArrow
            text: "→"
            color: Theme.primary
            font.pixelSize: 20
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: control.selected ? Theme.primarySoft
             : control.hovered ? Theme.surfaceAlt
             : Theme.surface
        border.width: control.selected ? 2 : 1
        border.color: control.selected ? Theme.primary : Theme.border

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
