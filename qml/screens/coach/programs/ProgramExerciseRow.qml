import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One exercise inside a program day: sets / reps / load / rest / notes.
//
// Reads its entry live from `program` (the editor's draft) so in-place edits
// don't rebuild the row. `week` 0 shows the all-weeks values; a week number
// shows that week's values; changes there apply to that week only.
//
// Reps and Load have modes, picked from their label (EntryModeField):
//   Reps: Reps (10, 8–10, 20+), Time in seconds (45, 30–45), Other
//   Load: Load in kg (80, 82.5), RPE (8, 7–8), 1RM % (75), Other
// Other is free text. Only the text is saved ("8–10", "45 s", "RPE 8",
// "75%", "Max"); the modes are worked out from it on load.
Rectangle {
    id: row

    property var program: null
    property int dayIndex: 0
    property int entryIndex: 0
    property int count: 1
    property int week: 0
    property int revision: 0        // bumped by the editor on every in-place edit
    property bool wide: true

    readonly property var entry: {
        const day = program && dayIndex < program.days.length ? program.days[dayIndex] : null
        return day && entryIndex < day.exercises.length
               ? day.exercises[entryIndex]
               : ({ exerciseId: "", sets: "", reps: "", load: "", rest: "", notes: "", weeks: {} })
    }
    readonly property var exercise: ProgramStore.exerciseById(entry.exerciseId, ProgramStore.revision)
    readonly property var changedKeys: ProgramStore.changedKeys(entry, week, revision)
    // Changing a mode replaces the draft, so these need no revision
    readonly property string repsMode: entry.repsMode ? entry.repsMode : "reps"
    readonly property string loadMode: entry.loadMode ? entry.loadMode : "load"

    // Typing limits per mode: a number or a range (typed with -, saved with –)
    readonly property var repsModes: [
        { mode: "reps", label: qsTr("Reps"), suffix: qsTr("reps"), placeholder: "10",
          pattern: /^\d{0,3}([-–]\d{0,3}|\+)?$/ },
        { mode: "time", label: qsTr("Time"), suffix: qsTr("s"), placeholder: "45",
          pattern: /^\d{0,4}([-–]\d{0,4})?$/ },
        { mode: "other", label: qsTr("Other"), suffix: "", placeholder: qsTr("Max, 250 m…"),
          pattern: null }
    ]
    readonly property var loadModes: [
        { mode: "load", label: qsTr("Load"), suffix: qsTr("kg"), placeholder: "80",
          pattern: /^\d{0,3}([.,]\d{0,2})?([-–]\d{0,3}([.,]\d{0,2})?)?$/ },
        { mode: "rpe", label: qsTr("RPE"), suffix: qsTr("RPE"), placeholder: "8",
          pattern: /^((10|[1-9])([.,]5?)?)?([-–]((10|[1-9])([.,]5?)?)?)?$/ },
        { mode: "percent", label: qsTr("1RM %"), suffix: "%", placeholder: "75",
          pattern: /^\d{0,3}([-–]\d{0,3})?$/ },
        { mode: "other", label: qsTr("Other"), suffix: "", placeholder: qsTr("Bodyweight, band…"),
          pattern: null }
    ]

    signal fieldEdited(string key, string value)
    signal fieldModeRequested(string key, string mode)
    signal moveRequested(int delta)
    signal removeRequested()
    signal resetWeekRequested()

    function value(key) {
        return ProgramStore.effective(entry, week, key)
    }

    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: Theme.background
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: row.entryIndex + 1
                color: Theme.textMuted
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 20
            }
            // Small drawing of the exercise, if it has one
            Rectangle {
                visible: row.exercise !== null && row.exercise.image.length > 0
                radius: Theme.radius
                color: Theme.surfaceAlt
                Layout.preferredWidth: row.wide ? 64 : 48
                Layout.preferredHeight: row.wide ? 64 : 48

                ExerciseImage {
                    anchors.fill: parent
                    anchors.margins: 4
                    drawing: row.exercise ? row.exercise.image : ""
                    // Decoded small: lines stay clean, and it saves memory
                    sourceSize.width: 2 * width
                    sourceSize.height: 2 * height
                }
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Label {
                    text: row.exercise ? row.exercise.name : qsTr("Deleted exercise")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    visible: row.exercise !== null
                    text: row.exercise ? row.exercise.muscleLabel + " · " + row.exercise.equipment : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            IconButton {
                glyph: "↑"
                tooltip: qsTr("Move up")
                enabled: row.entryIndex > 0
                onClicked: row.moveRequested(-1)
            }
            IconButton {
                glyph: "↓"
                tooltip: qsTr("Move down")
                enabled: row.entryIndex < row.count - 1
                onClicked: row.moveRequested(1)
            }
            IconButton {
                glyph: "✕"
                tooltip: qsTr("Remove from this day")
                destructive: true
                onClicked: row.removeRequested()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: row.wide ? 30 : 0
            columns: row.wide ? 5 : 3
            columnSpacing: 8
            rowSpacing: 8

            AuraTextField {
                id: setsField
                label: qsTr("Sets")
                text: row.value("sets")
                fieldHeight: 36
                validator: IntValidator { bottom: 1; top: 99 }
                inputMethodHints: Qt.ImhDigitsOnly
                Layout.preferredWidth: 64
                Layout.fillWidth: false
                onTextEdited: row.fieldEdited("sets", setsField.text)
            }
            // Modes cover every week, so they can only be changed in the
            // all-weeks view
            EntryModeField {
                modes: row.repsModes
                mode: row.repsMode
                storedText: row.value("reps")
                modeEditable: row.week === 0
                Layout.preferredWidth: 112
                Layout.fillWidth: false
                onEdited: stored => row.fieldEdited("reps", stored)
                onModeRequested: mode => row.fieldModeRequested("reps", mode)
            }
            EntryModeField {
                modes: row.loadModes
                mode: row.loadMode
                storedText: row.value("load")
                modeEditable: row.week === 0
                Layout.preferredWidth: row.wide ? 150 : -1
                Layout.fillWidth: !row.wide
                onEdited: stored => row.fieldEdited("load", stored)
                onModeRequested: mode => row.fieldModeRequested("load", mode)
            }
            AuraTextField {
                id: restField
                label: qsTr("Rest (sec)")
                text: row.entry.rest
                enabled: row.week === 0
                fieldHeight: 36
                validator: IntValidator { bottom: 0; top: 999 }
                inputMethodHints: Qt.ImhDigitsOnly
                Layout.preferredWidth: 80
                Layout.fillWidth: false
                onTextEdited: row.fieldEdited("rest", restField.text)
            }
            AuraTextField {
                id: notesField
                label: qsTr("Notes")
                text: row.entry.notes
                enabled: row.week === 0
                placeholderText: qsTr("Tempo, cues…")
                fieldHeight: 36
                Layout.fillWidth: true
                Layout.columnSpan: row.wide ? 1 : 2
                onTextEdited: row.fieldEdited("notes", notesField.text)
            }
        }

        // This week has its own values: offer to go back to the all-weeks ones
        AuraButton {
            visible: row.week > 0 && row.changedKeys.length > 0
            Layout.leftMargin: row.wide ? 30 : 0
            variant: "ghost"
            text: qsTr("Use the all-weeks values")
            implicitHeight: 28
            leftPadding: 8
            rightPadding: 8
            font.pixelSize: Theme.fontSmall
            onClicked: row.resetWeekRequested()
        }
    }
}
