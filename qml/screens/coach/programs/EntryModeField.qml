pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// A program-entry field with modes, used for Reps (Reps / Time / Other) and
// Load (Load / RPE / 1RM % / Other). Its label is a menu to switch mode. The
// field shows only the number, with the unit after it; ProgramStore turns it
// into the stored text ("45" in Time -> "45 s", "8" in RPE -> "RPE 8").
// "other" is free text.
ColumnLayout {
    id: field

    // [{ mode, label, suffix, placeholder, pattern }]; pattern limits typing
    // (a RegExp), null for free text
    property var modes: []
    property string mode: ""
    property string storedText: ""          // the entry's text for the shown week
    property bool modeEditable: true        // false in a week view: modes cover every week

    signal edited(string stored)
    signal modeRequested(string mode)

    readonly property var current: {
        const found = modes.find(m => m.mode === mode)
        return found ? found : (modes.length > 0 ? modes[0] : ({ mode: "other", label: "", suffix: "", placeholder: "", pattern: null }))
    }

    spacing: 6

    RegularExpressionValidator {
        id: patternValidator
        regularExpression: field.current.pattern ? field.current.pattern : /.*/
    }

    Label {
        id: caption
        text: field.current.label + (field.modeEditable ? " ▾" : "")
        color: captionArea.containsMouse ? Theme.primary : Theme.text
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold

        MouseArea {
            id: captionArea
            anchors.fill: parent
            anchors.margins: -4
            enabled: field.modeEditable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.popup(caption, 0, caption.height + 4)
        }
    }

    AuraTextField {
        id: input
        text: ProgramStore.modeInput(field.storedText, field.mode)
        suffix: field.current.suffix
        validator: field.current.pattern ? patternValidator : null
        placeholderText: field.current.placeholder
        fieldHeight: 36
        Layout.fillWidth: true
        onTextEdited: field.edited(ProgramStore.modeStored(input.text, field.mode))
    }

    AuraMenu {
        id: menu

        Instantiator {
            model: field.modes
            delegate: Action {
                required property var modelData
                text: modelData.label
                checked: modelData.mode === field.mode
                onTriggered: field.modeRequested(modelData.mode)
            }
            onObjectAdded: (index, object) => menu.insertAction(index, object)
            onObjectRemoved: (index, object) => menu.removeAction(object)
        }
    }
}
