import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Checklist row. Toggle by handling clicked and flipping `done` in the model.
AbstractButton {
    id: control

    property bool done: false

    hoverEnabled: true
    padding: 5
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: RowLayout {
        spacing: 12

        Rectangle {
            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: control.done ? Theme.primary : "transparent"
            border.width: control.done ? 0 : 2
            border.color: control.hovered ? Theme.primary : Theme.border

            Label {
                anchors.centerIn: parent
                visible: control.done
                text: "✓"
                color: Theme.textOnPrimary
                font.pixelSize: 14
                font.bold: true
            }
        }

        Label {
            text: control.text
            color: control.done ? Theme.textMuted : Theme.text
            font.strikeout: control.done
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    background: Rectangle {
        radius: 8
        color: control.hovered ? Theme.surfaceAlt : "transparent"
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
