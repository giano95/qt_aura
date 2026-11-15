import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Surface container with an optional title. Children are stacked vertically.
Rectangle {
    id: root

    default property alias content: body.data
    property string title: ""
    property int padding: 20

    color: Theme.surface
    radius: Theme.radiusLarge
    border.width: 1
    border.color: Theme.border
    implicitWidth: layout.implicitWidth + 2 * padding
    implicitHeight: layout.implicitHeight + 2 * padding

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 14

        Label {
            visible: root.title.length > 0
            text: root.title
            font.pixelSize: Theme.fontLarge
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 12
        }

        // Keeps content top-aligned when the card is stretched
        Item { Layout.fillHeight: true }
    }
}
