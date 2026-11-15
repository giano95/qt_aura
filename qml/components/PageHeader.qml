import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Page title + subtitle, with actions (children) on the right.
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias actions: actionRow.data

    spacing: 16

    ColumnLayout {
        spacing: 4
        Layout.fillWidth: true

        Label {
            text: root.title
            font.pixelSize: Theme.fontHeadline
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: root.subtitle
            color: Theme.textMuted
            font.pixelSize: Theme.fontLarge
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    RowLayout {
        id: actionRow
        spacing: 8
        Layout.alignment: Qt.AlignTop
    }
}
