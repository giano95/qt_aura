pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Create or edit an exercise in the library.
AuraDialog {
    id: dialog

    property string exerciseId: ""
    // Built-in library exercises are read-only
    property bool builtIn: false
    property var muscles: []                // groups worked
    property var subMuscles: []             // parts of them: at least one per group (Cardio has none)
    property string equipment: ""
    property string presetMuscle: ""        // preselected group and part for new exercises
    property string presetSubMuscle: ""
    property bool submitted: false

    readonly property bool isNew: exerciseId === ""
    readonly property int usage: exerciseId !== "" ? ProgramStore.usageCount(exerciseId, ProgramStore.revision) : 0

    readonly property string nameError: {
        if (!submitted)
            return ""
        if (nameField.text.trim().length === 0)
            return qsTr("Enter a name.")
        if (ProgramStore.isExerciseNameTaken(nameField.text, exerciseId, ProgramStore.revision))
            return qsTr("An exercise with this name already exists.")
        return ""
    }
    // Chosen groups with none of their parts chosen yet
    readonly property var groupsMissingParts: Array.from(ProgramStore.groupsMissingParts(muscles, subMuscles))
    readonly property string muscleError: {
        if (!submitted)
            return ""
        if (muscles.length === 0)
            return qsTr("Choose at least one muscle group.")
        if (groupsMissingParts.length > 0)
            return qsTr("Choose at least one part of %1.").arg(groupsMissingParts.join(", "))
        return ""
    }
    readonly property string equipmentError: submitted && equipment === "" ? qsTr("Choose the equipment.") : ""

    signal saved(string exerciseId)

    function openNew(name) {
        exerciseId = ""
        builtIn = false
        nameField.text = name || ""
        muscles = presetMuscle !== "" ? [presetMuscle] : []
        subMuscles = presetSubMuscle !== "" ? [presetSubMuscle] : []
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
        builtIn = e.builtIn
        nameField.text = e.name
        muscles = Array.from(e.muscles)
        subMuscles = Array.from(e.subMuscles)
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
            muscles: muscles,
            subMuscles: subMuscles,
            equipment: equipment,
            instructions: instructionsField.text,
            videoUrl: videoField.text
        })
        close()
        saved(id)
    }

    title: isNew ? qsTr("New exercise") : builtIn ? qsTr("Built-in exercise") : qsTr("Edit exercise")
    preferredWidth: 580
    onOpened: {
        if (!builtIn)
            nameField.focusInput()
    }

    Notice {
        tone: "info"
        visible: dialog.builtIn
        Layout.fillWidth: true
        text: qsTr("This exercise is part of the built-in library, so it can't be changed. To adapt it, create your own exercise with a different name.")
    }

    AuraTextField {
        id: nameField
        Layout.fillWidth: true
        label: qsTr("Name")
        placeholderText: qsTr("e.g. Cable crunch")
        enabled: !dialog.builtIn
        errorText: dialog.nameError
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        Label {
            text: qsTr("Muscle groups")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        MusclePicker {
            visible: !dialog.builtIn
            muscles: dialog.muscles
            subMuscles: dialog.subMuscles
            missingGroups: dialog.submitted ? dialog.groupsMissingParts : []
            Layout.fillWidth: true
            onChosen: (groups, parts) => {
                dialog.muscles = groups
                dialog.subMuscles = parts
            }
        }
        // Built-in exercises only show what's chosen, a line per group:
        // group › its parts
        Repeater {
            model: dialog.builtIn ? dialog.muscles : []

            Flow {
                id: groupLine
                required property string modelData
                readonly property var parts: ProgramStore.subMuscles(modelData)
                                                 .filter(p => dialog.subMuscles.includes(p))
                spacing: 6
                Layout.fillWidth: true

                Chip {
                    text: groupLine.modelData
                    tone: "primary"
                }
                Label {
                    visible: groupLine.parts.length > 0
                    text: "›"
                    color: Theme.textMuted
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                }
                Repeater {
                    model: groupLine.parts
                    Chip {
                        required property string modelData
                        text: modelData
                        tone: "primary"
                    }
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
            visible: !dialog.builtIn
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
        Chip {
            visible: dialog.builtIn
            text: dialog.equipment
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
        enabled: !dialog.builtIn
    }

    AuraTextField {
        id: videoField
        Layout.fillWidth: true
        label: qsTr("Video link (optional)")
        placeholderText: "https://"
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        enabled: !dialog.builtIn
    }

    leftActions: AuraButton {
        visible: !dialog.isNew && !dialog.builtIn
        enabled: dialog.usage === 0
        variant: "ghostDanger"
        text: qsTr("Delete")
        onClicked: deleteDialog.open()
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: dialog.builtIn ? qsTr("Close") : qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            visible: !dialog.builtIn
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
