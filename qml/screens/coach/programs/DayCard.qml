pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One training day in the program editor: editable name, list of exercises,
// "Add exercise" button and a menu with day actions.
// Reads the day live from `program` (the editor's draft).
Rectangle {
    id: card

    property var program: null
    property int dayIndex: 0
    property int week: 0
    property int revision: 0
    property bool wide: true

    readonly property var day: program && dayIndex < program.days.length
                               ? program.days[dayIndex]
                               : ({ name: "", exercises: [] })
    readonly property int dayCount: program ? program.days.length : 0
    readonly property int exerciseCount: day.exercises.length

    signal nameEdited(string name)
    signal addExerciseRequested()
    signal moveRequested(int delta)
    signal duplicateRequested()
    signal deleteRequested()
    signal entryFieldEdited(int entryIndex, string key, string value)
    signal entryFieldModeRequested(int entryIndex, string key, string mode)
    signal entryMoveRequested(int entryIndex, int delta)
    signal entryRemoveRequested(int entryIndex)
    signal entryResetWeekRequested(int entryIndex)

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
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: Theme.primarySoft
                Label {
                    anchors.centerIn: parent
                    text: card.dayIndex + 1
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }

            TextField {
                id: nameInput
                Layout.fillWidth: true
                text: card.day.name
                placeholderText: qsTr("Day name, e.g. Upper body")
                font.pixelSize: Theme.fontLarge
                font.weight: Font.DemiBold
                color: Theme.text
                placeholderTextColor: Theme.textMuted
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                selectByMouse: true
                hoverEnabled: true
                leftPadding: 8
                rightPadding: 8
                implicitHeight: 38
                onTextEdited: card.nameEdited(nameInput.text)

                background: Rectangle {
                    radius: 8
                    color: nameInput.activeFocus ? Theme.surface
                         : nameInput.hovered ? Theme.surfaceAlt
                         : "transparent"
                    border.width: nameInput.activeFocus ? 2 : 0
                    border.color: Theme.primary
                }
            }

            Label {
                visible: card.wide
                text: card.exerciseCount === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(card.exerciseCount)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            IconButton {
                id: menuButton
                glyph: "⋯"
                tooltip: qsTr("Day options")
                onClicked: dayMenu.popup(menuButton, menuButton.width - dayMenu.width, menuButton.height + 4)
            }
        }

        Repeater {
            model: card.exerciseCount

            ProgramExerciseRow {
                required property int index
                Layout.fillWidth: true
                program: card.program
                dayIndex: card.dayIndex
                entryIndex: index
                count: card.exerciseCount
                week: card.week
                revision: card.revision
                wide: card.wide
                onFieldEdited: (key, value) => card.entryFieldEdited(index, key, value)
                onFieldModeRequested: (key, mode) => card.entryFieldModeRequested(index, key, mode)
                onMoveRequested: delta => card.entryMoveRequested(index, delta)
                onRemoveRequested: card.entryRemoveRequested(index)
                onResetWeekRequested: card.entryResetWeekRequested(index)
            }
        }

        Label {
            visible: card.exerciseCount === 0
            text: qsTr("No exercises yet. Add the first one from your library.")
            color: Theme.textMuted
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: card.wide ? 42 : 0
        }

        AuraButton {
            variant: "secondary"
            text: qsTr("+ Add exercise")
            Layout.leftMargin: card.wide ? 42 : 0
            onClicked: card.addExerciseRequested()
        }
    }

    AuraMenu {
        id: dayMenu

        Action {
            text: qsTr("Move day up")
            enabled: card.dayIndex > 0
            onTriggered: card.moveRequested(-1)
        }
        Action {
            text: qsTr("Move day down")
            enabled: card.dayIndex < card.dayCount - 1
            onTriggered: card.moveRequested(1)
        }
        Action {
            text: qsTr("Duplicate day")
            onTriggered: card.duplicateRequested()
        }
        Action {
            text: qsTr("Delete day")
            objectName: "destructive"
            enabled: card.dayCount > 1
            onTriggered: card.deleteRequested()
        }
    }
}
