pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Choose the muscles an exercise works (exercise form): any number of groups
// and, under each chosen group, indented, its parts. Each chosen group needs
// at least one part (Cardio has none); the form checks that and passes the
// groups still missing one in missingGroups. Unchoosing a group also drops
// its parts.
// The owner keeps the choice: it reacts to chosen() and binds it back.
ColumnLayout {
    id: root

    property var muscles: []
    property var subMuscles: []
    property var missingGroups: []      // shown in red

    // Chosen groups that have parts, in display order
    readonly property var openGroups: ProgramStore.muscleGroups.filter(
        g => root.muscles.includes(g) && ProgramStore.subMuscles(g).length > 0)

    signal chosen(var muscles, var subMuscles)

    function toggleGroup(group) {
        if (muscles.includes(group)) {
            const parts = ProgramStore.subMuscles(group)
            chosen(muscles.filter(m => m !== group), subMuscles.filter(p => !parts.includes(p)))
        } else {
            chosen(Array.from(muscles).concat([group]), subMuscles)
        }
    }

    function togglePart(part) {
        chosen(muscles, subMuscles.includes(part) ? subMuscles.filter(p => p !== part)
                                                  : Array.from(subMuscles).concat([part]))
    }

    spacing: 8

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: ProgramStore.muscleGroups
            FilterChip {
                required property string modelData
                text: modelData
                selected: root.muscles.includes(modelData)
                onClicked: root.toggleGroup(modelData)
            }
        }
    }

    // One branch per chosen group, with its parts
    Repeater {
        model: root.openGroups

        RowLayout {
            id: branch
            required property string modelData

            Layout.fillWidth: true
            Layout.leftMargin: 14
            spacing: 12

            Rectangle {
                implicitWidth: 2
                radius: 1
                color: Theme.border
                Layout.fillHeight: true
            }
            ColumnLayout {
                spacing: 6
                Layout.fillWidth: true

                Label {
                    text: qsTr("Parts of %1").arg(branch.modelData)
                    color: root.missingGroups.includes(branch.modelData) ? Theme.danger : Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ProgramStore.subMuscles(branch.modelData)
                        FilterChip {
                            required property string modelData
                            text: modelData
                            selected: root.subMuscles.includes(modelData)
                            onClicked: root.togglePart(modelData)
                        }
                    }
                }
            }
        }
    }
}
