import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// "Good morning, Name" page header. Children are placed on the right as actions.
RowLayout {
    id: root

    property string name: ""
    property string subtitle: ""
    default property alias actions: actionRow.data

    function greeting() {
        const hour = new Date().getHours()
        if (hour < 12)
            return qsTr("Good morning")
        if (hour < 18)
            return qsTr("Good afternoon")
        return qsTr("Good evening")
    }

    spacing: 16

    ColumnLayout {
        spacing: 4
        Layout.fillWidth: true

        Label {
            text: root.greeting() + ", " + root.name
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
