pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Exercises section (its own entry in the coach sidebar): the exercise
// library. Search, filter by muscle group, add and edit exercises.
ScrollView {
    id: page

    property string muscle: ""          // "" = all groups
    property string subMuscle: ""       // "" = any part of the group

    readonly property var results: ProgramStore.searchExercises(search.text, muscle, subMuscle, ProgramStore.revision)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((availableWidth + 16) / 296)))

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 16

        PageHeader {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            title: qsTr("Exercise library")
            subtitle: qsTr("Every exercise you can add to a program. Add your own anytime.")

            AuraButton {
                text: qsTr("New exercise")
                onClicked: formDialog.openNew("")
            }
        }

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
                text: page.results.length === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(page.results.length)
                color: Theme.textMuted
            }
        }

        MuscleFilter {
            Layout.fillWidth: true
            muscle: page.muscle
            subMuscle: page.subMuscle
            onPicked: (group, part) => {
                page.muscle = group
                page.subMuscle = part
            }
        }

        GridLayout {
            visible: page.results.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            columns: page.columns
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: page.results

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
            visible: page.results.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 40
            title: search.text.length > 0 ? qsTr("No exercises match \"%1\"").arg(search.text)
                                          : qsTr("No exercises in this group yet")
            message: qsTr("Add it to your library and it will be available in every program.")

            AuraButton {
                text: search.text.length > 0 ? qsTr("Create \"%1\"").arg(search.text) : qsTr("New exercise")
                onClicked: formDialog.openNew(search.text)
            }
        }

        ExerciseFormDialog {
            id: formDialog
            presetMuscle: page.muscle
            presetSubMuscle: page.subMuscle
        }
    }
}
