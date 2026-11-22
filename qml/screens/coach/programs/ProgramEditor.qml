pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Create or edit a program: details, training days, the exercises in each day,
// and week-by-week changes to sets / reps / load.
//
// Editing works on a private copy (`draft`). Nothing reaches ProgramStore until
// the coach saves. Text edits change the draft in place and bump `revision`
// (so fields keep focus); structural edits (add / move / remove) replace the
// draft, which refreshes the day list.
Item {
    id: editor

    property string programId: ""            // "" = new program
    property var draft: ({ id: "", name: "", description: "", weeks: "", updatedAt: 0, days: [] })
    property int revision: 0
    property int week: 0                    // 0 = all weeks
    property bool dirty: false
    property string nameError: ""
    property int pickerDayIndex: -1
    property int pendingDeleteDay: -1

    // Set when opened from somewhere else (e.g. a client's page): the back
    // button returns there instead of to the program list.
    property string backText: qsTr("← Programs")
    property bool returnOnClose: false

    // Another program asked to open while this one has unsaved changes
    property string pendingSwitchId: ""
    property string pendingSwitchBackText: ""

    readonly property bool isNew: draft.id === ""
    readonly property bool wide: width >= 760
    readonly property int totalExercises: ProgramStore.exerciseCount(draft)
    readonly property int weekCount: ProgramStore.weekCount(draft, revision)
    readonly property var changedWeeks: ProgramStore.programChangedWeeks(draft, revision)
    readonly property int clientCount: ClientStore.countForProgram(draft.id)

    signal closeRequested()
    signal switchRequested(string programId, string backText)

    Component.onCompleted: {
        draft = programId !== "" ? ProgramStore.cloneProgram(programId) : ProgramStore.newProgramDraft()
    }

    onWeekCountChanged: {
        if (week > weekCount)
            week = 0
    }

    // ---- editing ------------------------------------------------------------

    function update(mutate) {
        const copy = JSON.parse(JSON.stringify(draft))
        mutate(copy)
        draft = copy
        dirty = true
    }

    function touch() {
        revision += 1
        dirty = true
    }

    function setField(key, value) {
        draft[key] = value
        if (key === "name")
            nameError = ""
        touch()
    }

    function setDayName(dayIndex, value) {
        draft.days[dayIndex].name = value
        touch()
    }

    function setEntryField(dayIndex, entryIndex, key, value) {
        const entry = draft.days[dayIndex].exercises[entryIndex]
        if (week > 0 && ProgramStore.weeklyKeys.includes(key))
            ProgramStore.setWeekValue(entry, week, key, value)
        else
            entry[key] = value
        touch()
    }

    function resetWeek(dayIndex, entryIndex) {
        const w = week
        update(d => {
            const entry = d.days[dayIndex].exercises[entryIndex]
            if (entry.weeks)
                delete entry.weeks[w]
        })
    }

    function addDay() {
        update(d => d.days.push(ProgramStore.newDay(d.days.length + 1)))
        Qt.callLater(scrollToEnd)
    }

    function moveDay(index, delta) {
        update(d => d.days.splice(index + delta, 0, d.days.splice(index, 1)[0]))
    }

    function duplicateDay(index) {
        update(d => d.days.splice(index + 1, 0, ProgramStore.duplicateDay(d.days[index])))
    }

    function requestDeleteDay(index) {
        if (draft.days[index].exercises.length === 0) {
            update(d => d.days.splice(index, 1))
            return
        }
        pendingDeleteDay = index
        deleteDayDialog.open()
    }

    function addExercise(dayIndex, exerciseId) {
        update(d => d.days[dayIndex].exercises.push(ProgramStore.newEntry(exerciseId)))
    }

    function moveExercise(dayIndex, entryIndex, delta) {
        update(d => {
            const list = d.days[dayIndex].exercises
            list.splice(entryIndex + delta, 0, list.splice(entryIndex, 1)[0])
        })
    }

    function removeExercise(dayIndex, entryIndex) {
        update(d => d.days[dayIndex].exercises.splice(entryIndex, 1))
    }

    function openPicker(dayIndex) {
        pickerDayIndex = dayIndex
        picker.openFor(draft.days[dayIndex].name || qsTr("Day %1").arg(dayIndex + 1))
    }

    function save() {
        if (draft.name.trim().length === 0) {
            nameError = qsTr("Give the program a name.")
            scroll.contentItem.contentY = 0
            nameField.focusInput()
            return
        }
        const wasNew = isNew
        const id = ProgramStore.saveProgram(draft)
        draft = ProgramStore.cloneProgram(id)
        dirty = false
        toast.show(wasNew ? qsTr("Program created") : qsTr("Changes saved"))
    }

    // Open another program in place of this one, asking first if there are unsaved changes
    function requestSwitch(programId, newBackText) {
        if (!dirty) {
            switchRequested(programId, newBackText)
            return
        }
        pendingSwitchId = programId
        pendingSwitchBackText = newBackText
        discardDialog.open()
    }

    function requestClose() {
        pendingSwitchId = ""
        if (dirty)
            discardDialog.open()
        else
            closeRequested()
    }

    function scrollToEnd() {
        const flick = scroll.contentItem
        flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    // ---- layout -------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            color: Theme.surface

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: editor.wide ? 20 : 8
                anchors.rightMargin: editor.wide ? 24 : 12
                spacing: 8

                AuraButton {
                    variant: "ghost"
                    text: editor.backText
                    leftPadding: 12
                    rightPadding: 12
                    onClicked: editor.requestClose()
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: editor.dirty && editor.wide
                    text: qsTr("Unsaved changes")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
                AuraButton {
                    visible: !editor.isNew
                    variant: "ghostDanger"
                    text: qsTr("Delete")
                    leftPadding: 12
                    rightPadding: 12
                    onClicked: deleteProgramDialog.open()
                }
                AuraButton {
                    text: editor.isNew ? qsTr("Create program") : qsTr("Save")
                    enabled: editor.isNew || editor.dirty
                    onClicked: editor.save()
                }
            }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            padding: editor.wide ? 32 : 16

            ColumnLayout {
                width: Math.min(scroll.availableWidth, 1000)
                x: (scroll.availableWidth - width) / 2
                spacing: 20

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true

                    Label {
                        text: nameField.text.trim().length > 0 ? nameField.text
                            : editor.isNew ? qsTr("New program") : qsTr("Untitled program")
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        text: (editor.draft.days.length === 1 ? qsTr("1 day") : qsTr("%1 days").arg(editor.draft.days.length))
                              + " · "
                              + (editor.totalExercises === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(editor.totalExercises))
                              + " · "
                              + (editor.weekCount === 1 ? qsTr("1 week") : qsTr("%1 weeks").arg(editor.weekCount))
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontLarge
                    }
                }

                // ---- details ----
                Card {
                    title: qsTr("Details")
                    Layout.fillWidth: true

                    Notice {
                        tone: "info"
                        visible: editor.clientCount > 0
                        Layout.fillWidth: true
                        text: editor.clientCount === 1
                              ? qsTr("1 client is following this program. Saved changes show up in their plan.")
                              : qsTr("%1 clients are following this program. Saved changes show up in their plans.").arg(editor.clientCount)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: editor.wide ? 2 : 1
                        columnSpacing: 16
                        rowSpacing: 16

                        AuraTextField {
                            id: nameField
                            Layout.fillWidth: true
                            label: qsTr("Program name")
                            placeholderText: qsTr("e.g. Strength foundations")
                            text: editor.draft.name
                            errorText: editor.nameError
                            onTextEdited: editor.setField("name", nameField.text)
                        }
                        AuraTextField {
                            id: weeksField
                            Layout.preferredWidth: editor.wide ? 160 : -1
                            Layout.fillWidth: !editor.wide
                            Layout.alignment: Qt.AlignTop
                            label: qsTr("Duration (weeks)")
                            text: editor.draft.weeks
                            validator: IntValidator { bottom: 1; top: 52 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            onTextEdited: editor.setField("weeks", weeksField.text)
                        }
                    }

                    AuraTextArea {
                        id: descriptionField
                        Layout.fillWidth: true
                        label: qsTr("Description")
                        placeholderText: qsTr("Who it's for, the goal, how to progress…")
                        text: editor.draft.description
                        minimumHeight: 72
                        onTextEdited: editor.setField("description", descriptionField.text)
                    }
                }

                // ---- days + week selector ----
                ColumnLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    Label {
                        text: qsTr("Training days")
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                    }
                    Label {
                        text: qsTr("Days and exercises repeat every week. To change sets, reps or load for one week only, such as a deload or a test week, pick that week below.")
                        color: Theme.textMuted
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Flow {
                        spacing: 6
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        FilterChip {
                            text: qsTr("All weeks")
                            selected: editor.week === 0
                            onClicked: editor.week = 0
                        }
                        Repeater {
                            model: editor.weekCount
                            FilterChip {
                                required property int index
                                text: qsTr("Week %1").arg(index + 1)
                                selected: editor.week === index + 1
                                marked: editor.changedWeeks.includes(index + 1)
                                onClicked: editor.week = index + 1
                            }
                        }
                    }

                    Notice {
                        tone: "info"
                        visible: editor.week > 0
                        Layout.fillWidth: true
                        text: qsTr("Editing <b>week %1</b>. Sets, reps and load you change here apply to this week only and are highlighted. Rest, notes and the list of exercises are the same every week.").arg(editor.week)
                    }
                }

                Repeater {
                    model: editor.draft.days.length

                    DayCard {
                        required property int index
                        Layout.fillWidth: true
                        program: editor.draft
                        dayIndex: index
                        week: editor.week
                        revision: editor.revision
                        wide: editor.wide
                        onNameEdited: name => editor.setDayName(index, name)
                        onAddExerciseRequested: editor.openPicker(index)
                        onMoveRequested: delta => editor.moveDay(index, delta)
                        onDuplicateRequested: editor.duplicateDay(index)
                        onDeleteRequested: editor.requestDeleteDay(index)
                        onEntryFieldEdited: (entryIndex, key, value) => editor.setEntryField(index, entryIndex, key, value)
                        onEntryMoveRequested: (entryIndex, delta) => editor.moveExercise(index, entryIndex, delta)
                        onEntryRemoveRequested: entryIndex => editor.removeExercise(index, entryIndex)
                        onEntryResetWeekRequested: entryIndex => editor.resetWeek(index, entryIndex)
                    }
                }

                AbstractButton {
                    id: addDayButton
                    Layout.fillWidth: true
                    Layout.bottomMargin: 24
                    implicitHeight: 64
                    hoverEnabled: true
                    onClicked: editor.addDay()

                    contentItem: Label {
                        text: qsTr("+ Add day")
                        color: Theme.primary
                        font.pixelSize: Theme.fontLarge
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: Theme.radiusLarge
                        color: addDayButton.hovered ? Theme.primarySoft : "transparent"
                        border.width: 1.5
                        border.color: addDayButton.hovered ? Theme.primary : Theme.border
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    Toast {
        id: toast
    }

    // ---- dialogs ------------------------------------------------------------

    ExercisePickerDialog {
        id: picker
        onPicked: exerciseId => editor.addExercise(editor.pickerDayIndex, exerciseId)
        onCreateRequested: name => exerciseForm.openNew(name)
    }

    ExerciseFormDialog {
        id: exerciseForm
        presetMuscle: picker.muscle
        onSaved: exerciseId => {
            // Created from the picker: add it to the day right away
            if (picker.opened) {
                editor.addExercise(editor.pickerDayIndex, exerciseId)
                picker.markAdded(exerciseId)
            }
        }
    }

    ConfirmDialog {
        id: discardDialog
        title: qsTr("Discard changes?")
        message: qsTr("You have unsaved changes to this program. If you leave now they will be lost.")
        cancelText: qsTr("Keep editing")
        confirmText: qsTr("Discard")
        destructive: true
        onConfirmed: {
            if (editor.pendingSwitchId !== "")
                editor.switchRequested(editor.pendingSwitchId, editor.pendingSwitchBackText)
            else
                editor.closeRequested()
        }
    }

    ConfirmDialog {
        id: deleteProgramDialog
        title: qsTr("Delete program?")
        message: editor.clientCount > 0
                 ? qsTr("\"%1\" is being followed by %2 client(s). They keep it until it ends, but you won't be able to edit or assign it again. This can't be undone.")
                       .arg(nameField.text).arg(editor.clientCount)
                 : qsTr("\"%1\" will be deleted. This can't be undone.").arg(nameField.text)
        confirmText: qsTr("Delete program")
        destructive: true
        onConfirmed: {
            ProgramStore.deleteProgram(editor.draft.id)
            editor.closeRequested()
        }
    }

    ConfirmDialog {
        id: deleteDayDialog
        title: qsTr("Delete day?")
        message: editor.pendingDeleteDay >= 0 && editor.pendingDeleteDay < editor.draft.days.length
                 ? qsTr("\"%1\" and its %2 exercise(s) will be removed from the program.")
                       .arg(editor.draft.days[editor.pendingDeleteDay].name)
                       .arg(editor.draft.days[editor.pendingDeleteDay].exercises.length)
                 : ""
        confirmText: qsTr("Delete day")
        destructive: true
        onConfirmed: editor.update(d => d.days.splice(editor.pendingDeleteDay, 1))
    }
}
