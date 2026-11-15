import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One key number with a caption and a short note.
Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string note: ""
    property string tone: "neutral"

    implicitWidth: 160
    implicitHeight: column.implicitHeight + 36
    color: Theme.surface
    radius: Theme.radiusLarge
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 18
        spacing: 4

        Label {
            text: root.label
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Label {
            text: root.value
            font.pixelSize: Theme.fontHeadline
            font.weight: Font.Bold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: root.note
            color: Theme.toneColor(root.tone)
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
