pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Exercise library tab: search, filter by muscle group, add and edit exercises.
ColumnLayout {
    id: root

    property string muscle: ""          // "" = all groups

    readonly property var results: ProgramStore.searchExercises(search.text, muscle, ProgramStore.revision)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((width + 16) / 296)))

    function createExercise(name) {
        formDialog.openNew(name)
    }

    spacing: 16

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        AuraSearchField {
            id: search
            placeholderText: qsTr("Search by name or equipment")
            Layout.fillWidth: true
            Layout.maximumWidth: 420
        }
        Item { Layout.fillWidth: true }
        Label {
            text: root.results.length === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(root.results.length)
            color: Theme.textMuted
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        FilterChip {
            text: qsTr("All")
            count: String(ProgramStore.exercises.length)
            selected: root.muscle === ""
            onClicked: root.muscle = ""
        }
        Repeater {
            model: ProgramStore.muscleGroups
            FilterChip {
                required property string modelData
                text: modelData
                count: String(ProgramStore.countByMuscle(modelData, ProgramStore.revision))
                selected: root.muscle === modelData
                onClicked: root.muscle = modelData
            }
        }
    }

    GridLayout {
        visible: root.results.length > 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        columns: root.columns
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: root.results

            ExerciseCard {
                required property var modelData
                exercise: modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                onClicked: formDialog.openEdit(modelData.id)
            }
        }
    }

    EmptyState {
        visible: root.results.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 40
        title: search.text.length > 0 ? qsTr("No exercises match \"%1\"").arg(search.text)
                                      : qsTr("No exercises in this group yet")
        message: qsTr("Add it to your library and it will be available in every program.")

        AuraButton {
            text: search.text.length > 0 ? qsTr("Create \"%1\"").arg(search.text) : qsTr("New exercise")
            onClicked: root.createExercise(search.text)
        }
    }

    ExerciseFormDialog {
        id: formDialog
        presetMuscle: root.muscle
    }
}
