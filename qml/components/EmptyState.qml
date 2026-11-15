import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Centered message for empty lists and searches with no results.
// Children (usually a button) are placed under the message.
ColumnLayout {
    id: root

    property string title: ""
    property string message: ""
    default property alias actions: actionRow.data

    spacing: 8

    BrandMark {
        size: 40
        color: Theme.textMuted
        opacity: 0.5
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 8
    }
    Label {
        text: root.title
        font.pixelSize: Theme.fontLarge
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
    Label {
        visible: text.length > 0
        text: root.message
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
    RowLayout {
        id: actionRow
        spacing: 8
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
    }
}
