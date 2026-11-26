pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Filter by muscle (library, exercise picker): a row of groups and, under the
// chosen one, a row of its parts, indented, each with how many exercises work
// it. The owner keeps the selection: it reacts to picked() and binds it back.
ColumnLayout {
    id: root

    property string muscle: ""          // "" = all groups
    property string subMuscle: ""       // "" = any part of the group

    readonly property var parts: ProgramStore.subMuscles(muscle)

    signal picked(string muscle, string subMuscle)

    spacing: 8

    Flow {
        Layout.fillWidth: true
        spacing: 8

        FilterChip {
            text: qsTr("All")
            count: String(ProgramStore.exercises.length)
            selected: root.muscle === ""
            onClicked: root.picked("", "")
        }
        Repeater {
            model: ProgramStore.muscleGroups
            FilterChip {
                required property string modelData
                text: modelData
                count: String(ProgramStore.countByMuscle(modelData, "", ProgramStore.revision))
                selected: root.muscle === modelData
                onClicked: root.picked(modelData, "")
            }
        }
    }

    // Parts of the chosen group, hanging off it
    RowLayout {
        visible: root.parts.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 14
        spacing: 12

        Rectangle {
            implicitWidth: 2
            radius: 1
            color: Theme.border
            Layout.fillHeight: true
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            FilterChip {
                text: qsTr("All %1").arg(root.muscle)
                count: String(ProgramStore.countByMuscle(root.muscle, "", ProgramStore.revision))
                selected: root.subMuscle === ""
                onClicked: root.picked(root.muscle, "")
            }
            Repeater {
                model: root.parts
                FilterChip {
                    required property string modelData
                    text: modelData
                    count: String(ProgramStore.countByMuscle(root.muscle, modelData, ProgramStore.revision))
                    selected: root.subMuscle === modelData
                    onClicked: root.picked(root.muscle, modelData)
                }
            }
        }
    }
}
