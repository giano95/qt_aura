pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Segmented tab switcher.
Rectangle {
    id: root

    property var model: []
    property int currentIndex: 0

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 8
    radius: Theme.radius
    color: Theme.surfaceAlt

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.model

            AbstractButton {
                id: segment
                required property int index
                required property string modelData
                readonly property bool selected: index === root.currentIndex

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: segmentLabel.implicitWidth + 32
                hoverEnabled: true
                onClicked: root.currentIndex = index

                contentItem: Label {
                    id: segmentLabel
                    text: segment.modelData
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    color: segment.selected || segment.hovered ? Theme.text : Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: Theme.radius - 3
                    color: segment.selected ? Theme.surface : "transparent"
                    border.width: segment.selected ? 1 : 0
                    border.color: Theme.border
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
