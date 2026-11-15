import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One exercise inside a program day: sets / reps / load / rest / notes.
//
// Reads its entry live from `program` (the editor's draft) so in-place edits
// don't rebuild the row. `week` 0 shows the all-weeks values; a week number
// shows that week's values, with changed fields highlighted.
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
               : ({ exerciseId: 0, sets: "", reps: "", load: "", rest: "", notes: "", weeks: {} })
    }
    readonly property var exercise: ProgramStore.exerciseById(entry.exerciseId)
    readonly property var changedKeys: ProgramStore.changedKeys(entry, week, revision)
    readonly property var changedWeeks: ProgramStore.entryChangedWeeks(entry, revision)

    signal fieldEdited(string key, string value)
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
                    text: row.exercise ? row.exercise.muscle + " · " + row.exercise.equipment : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Chip {
                visible: row.week === 0 && row.changedWeeks.length > 0 && row.wide
                tone: "accent"
                text: row.changedWeeks.length === 1
                      ? qsTr("Changes in week %1").arg(row.changedWeeks[0])
                      : qsTr("Changes in weeks %1").arg(row.changedWeeks.join(", "))
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
                highlighted: row.changedKeys.includes("sets")
                fieldHeight: 36
                validator: IntValidator { bottom: 1; top: 99 }
                inputMethodHints: Qt.ImhDigitsOnly
                Layout.preferredWidth: 64
                Layout.fillWidth: false
                onTextEdited: row.fieldEdited("sets", setsField.text)
            }
            AuraTextField {
                id: repsField
                label: qsTr("Reps / time")
                text: row.value("reps")
                highlighted: row.changedKeys.includes("reps")
                placeholderText: "10"
                fieldHeight: 36
                Layout.preferredWidth: 112
                Layout.fillWidth: false
                onTextEdited: row.fieldEdited("reps", repsField.text)
            }
            AuraTextField {
                id: loadField
                label: qsTr("Load")
                text: row.value("load")
                highlighted: row.changedKeys.includes("load")
                placeholderText: qsTr("kg, %, RPE")
                fieldHeight: 36
                Layout.preferredWidth: row.wide ? 150 : -1
                Layout.fillWidth: !row.wide
                onTextEdited: row.fieldEdited("load", loadField.text)
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

        RowLayout {
            visible: row.week > 0 && row.changedKeys.length > 0
            Layout.leftMargin: row.wide ? 30 : 0
            spacing: 8

            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: Theme.accent
            }
            Label {
                text: qsTr("Different in week %1").arg(row.week)
                color: Theme.accent
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            AuraButton {
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
}
