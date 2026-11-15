pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Create or edit an exercise in the library.
AuraDialog {
    id: dialog

    property int exerciseId: 0
    property string muscle: ""
    property string equipment: ""
    property string presetMuscle: ""        // preselected group for new exercises
    property bool submitted: false

    readonly property bool isNew: exerciseId === 0
    readonly property int usage: exerciseId !== 0 ? ProgramStore.usageCount(exerciseId) : 0

    readonly property string nameError: {
        if (!submitted)
            return ""
        if (nameField.text.trim().length === 0)
            return qsTr("Enter a name.")
        if (ProgramStore.isExerciseNameTaken(nameField.text, exerciseId))
            return qsTr("An exercise with this name already exists.")
        return ""
    }
    readonly property string muscleError: submitted && muscle === "" ? qsTr("Choose a muscle group.") : ""
    readonly property string equipmentError: submitted && equipment === "" ? qsTr("Choose the equipment.") : ""

    signal saved(int exerciseId)

    function openNew(name) {
        exerciseId = 0
        nameField.text = name || ""
        muscle = presetMuscle
        equipment = ""
        instructionsField.text = ""
        videoField.text = ""
        submitted = false
        open()
    }

    function openEdit(id) {
        const e = ProgramStore.exerciseById(id)
        if (!e)
            return
        exerciseId = id
        nameField.text = e.name
        muscle = e.muscle
        equipment = e.equipment
        instructionsField.text = e.instructions
        videoField.text = e.videoUrl
        submitted = false
        open()
    }

    function save() {
        submitted = true
        if (nameError || muscleError || equipmentError)
            return
        const id = ProgramStore.saveExercise({
            id: exerciseId,
            name: nameField.text,
            muscle: muscle,
            equipment: equipment,
            instructions: instructionsField.text,
            videoUrl: videoField.text
        })
        close()
        saved(id)
    }

    title: isNew ? qsTr("New exercise") : qsTr("Edit exercise")
    preferredWidth: 580
    onOpened: nameField.focusInput()

    Notice {
        tone: "info"
        visible: !dialog.isNew && dialog.usage > 0
        Layout.fillWidth: true
        text: (dialog.usage === 1 ? qsTr("Used in 1 program.") : qsTr("Used in %1 programs.").arg(dialog.usage))
              + " " + qsTr("Changes apply everywhere it's used.")
    }

    AuraTextField {
        id: nameField
        Layout.fillWidth: true
        label: qsTr("Name")
        placeholderText: qsTr("e.g. Cable crunch")
        errorText: dialog.nameError
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        Label {
            text: qsTr("Muscle group")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        Flow {
            spacing: 8
            Layout.fillWidth: true
            Repeater {
                model: ProgramStore.muscleGroups
                FilterChip {
                    required property string modelData
                    text: modelData
                    selected: dialog.muscle === modelData
                    onClicked: dialog.muscle = modelData
                }
            }
        }
        Label {
            visible: text.length > 0
            text: dialog.muscleError
            color: Theme.danger
            font.pixelSize: Theme.fontSmall
        }
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        Label {
            text: qsTr("Equipment")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        Flow {
            spacing: 8
            Layout.fillWidth: true
            Repeater {
                model: ProgramStore.equipmentTypes
                FilterChip {
                    required property string modelData
                    text: modelData
                    selected: dialog.equipment === modelData
                    onClicked: dialog.equipment = modelData
                }
            }
        }
        Label {
            visible: text.length > 0
            text: dialog.equipmentError
            color: Theme.danger
            font.pixelSize: Theme.fontSmall
        }
    }

    AuraTextArea {
        id: instructionsField
        Layout.fillWidth: true
        label: qsTr("Instructions")
        placeholderText: qsTr("How to perform it, key cues, common mistakes…")
    }

    AuraTextField {
        id: videoField
        Layout.fillWidth: true
        label: qsTr("Video link (optional)")
        placeholderText: "https://"
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
    }

    leftActions: AuraButton {
        visible: !dialog.isNew
        enabled: dialog.usage === 0
        variant: "ghostDanger"
        text: qsTr("Delete")
        onClicked: deleteDialog.open()
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: dialog.isNew ? qsTr("Add exercise") : qsTr("Save changes")
            onClicked: dialog.save()
        }
    ]

    ConfirmDialog {
        id: deleteDialog
        title: qsTr("Delete exercise?")
        message: qsTr("\"%1\" will be removed from your library. This can't be undone.").arg(nameField.text)
        confirmText: qsTr("Delete")
        destructive: true
        onConfirmed: {
            ProgramStore.deleteExercise(dialog.exerciseId)
            dialog.close()
        }
    }
}
