pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Search the library and add exercises to a program day. Stays open so the
// coach can add several in a row.
AuraDialog {
    id: dialog

    property string dayName: ""
    property string muscle: ""
    property string subMuscle: ""
    property var addedCounts: ({})       // exerciseId -> times added while open
    property int addedTotal: 0

    readonly property var results: ProgramStore.searchExercises(search.text, muscle, subMuscle, ProgramStore.revision)

    signal picked(string exerciseId)
    signal createRequested(string name)

    function openFor(name) {
        dayName = name
        muscle = ""
        subMuscle = ""
        addedCounts = ({})
        addedTotal = 0
        search.text = ""
        open()
    }

    function markAdded(exerciseId) {
        const counts = Object.assign({}, addedCounts)
        counts[exerciseId] = (counts[exerciseId] || 0) + 1
        addedCounts = counts
        addedTotal += 1
    }

    title: qsTr("Add exercises")
    preferredWidth: 620
    scrollable: false
    onOpened: search.forceActiveFocus()

    Label {
        text: qsTr("Adding to <b>%1</b>. Click an exercise to add it; you can add several.").arg(dialog.dayName)
        textFormat: Text.StyledText
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    AuraSearchField {
        id: search
        placeholderText: qsTr("Search exercises")
        Layout.fillWidth: true
    }

    MuscleFilter {
        Layout.fillWidth: true
        muscle: dialog.muscle
        subMuscle: dialog.subMuscle
        onPicked: (group, part) => {
            dialog.muscle = group
            dialog.subMuscle = part
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(180, Math.min(360, (dialog.parent ? dialog.parent.height : 800) - 430))
        clip: true
        spacing: 2
        model: dialog.results
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        delegate: AbstractButton {
            id: row
            required property var modelData
            readonly property int timesAdded: dialog.addedCounts[modelData.id] || 0

            width: ListView.view.width
            implicitHeight: 56
            hoverEnabled: true
            leftPadding: 12
            rightPadding: 12
            onClicked: {
                dialog.markAdded(modelData.id)
                dialog.picked(modelData.id)
            }

            contentItem: RowLayout {
                spacing: 12

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    Label {
                        text: row.modelData.name
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: row.modelData.muscleLabel + " · " + row.modelData.equipment
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Chip {
                    visible: row.timesAdded > 0
                    tone: "primary"
                    text: row.timesAdded === 1 ? qsTr("✓ Added") : qsTr("✓ Added ×%1").arg(row.timesAdded)
                }
                Label {
                    text: qsTr("+ Add")
                    color: Theme.primary
                    font.weight: Font.DemiBold
                    opacity: row.hovered ? 1 : 0.7
                }
            }

            background: Rectangle {
                radius: Theme.radius
                color: row.hovered ? Theme.surfaceAlt : "transparent"
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        EmptyState {
            anchors.centerIn: parent
            width: parent.width - 48
            visible: list.count === 0
            title: search.text.length > 0 ? qsTr("No exercises match \"%1\"").arg(search.text)
                                          : qsTr("No exercises in this group")

            AuraButton {
                text: search.text.length > 0 ? qsTr("Create \"%1\"").arg(search.text) : qsTr("New exercise")
                onClicked: dialog.createRequested(search.text)
            }
        }
    }

    leftActions: AuraButton {
        variant: "ghost"
        text: qsTr("+ New exercise")
        onClicked: dialog.createRequested(search.text)
    }

    actions: AuraButton {
        text: dialog.addedTotal > 0 ? qsTr("Done · %1 added").arg(dialog.addedTotal) : qsTr("Done")
        onClicked: dialog.close()
    }
}
