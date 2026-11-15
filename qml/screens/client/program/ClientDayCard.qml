pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One training day as the client sees it (read-only).
Rectangle {
    id: card

    property var day: ({ name: "", exercises: [] })
    property int dayNumber: 1
    property int week: 1
    property bool wide: true

    implicitHeight: column.implicitHeight + 2 * column.anchors.margins
    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.wide ? 20 : 14
        spacing: 8

        RowLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.bottomMargin: 4

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: Theme.primarySoft
                Label {
                    anchors.centerIn: parent
                    text: card.dayNumber
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }
            Label {
                text: card.day.name || qsTr("Day %1").arg(card.dayNumber)
                font.pixelSize: Theme.fontLarge
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                text: card.day.exercises.length === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(card.day.exercises.length)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
        }

        Repeater {
            model: card.day.exercises

            ClientExerciseRow {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                entry: modelData
                position: index + 1
                week: card.week
                wide: card.wide
            }
        }

        Label {
            visible: card.day.exercises.length === 0
            text: qsTr("Rest day")
            color: Theme.textMuted
        }
    }
}
