import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Labeled text field with an error message underneath, an optional
// show/hide toggle for passwords and an optional unit after the text
// (`suffix`, e.g. "reps" or "s").
ColumnLayout {
    id: root

    property alias label: caption.text
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputMethodHints: input.inputMethodHints
    property alias validator: input.validator
    property alias horizontalAlignment: input.horizontalAlignment
    property int fieldHeight: Theme.controlHeight
    property bool isPassword: false
    property string suffix: ""           // unit shown inside the field, on the right
    property string errorText: ""
    property bool highlighted: false     // accent style, e.g. a value changed for one week

    signal accepted()
    signal textEdited()

    function focusInput() {
        input.forceActiveFocus()
    }

    property bool _revealed: false

    spacing: 6
    opacity: enabled ? 1 : 0.55

    Label {
        id: caption
        visible: text.length > 0
        color: Theme.text
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
    }

    TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: root.fieldHeight
        leftPadding: root.fieldHeight < Theme.controlHeight ? 10 : 14
        rightPadding: root.isPassword ? revealToggle.width + 24
                    : root.suffix.length > 0 ? suffixText.width + leftPadding + 6
                    : leftPadding
        color: Theme.text
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.fontBody
        echoMode: root.isPassword && !root._revealed ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        onAccepted: root.accepted()
        onTextEdited: root.textEdited()

        background: Rectangle {
            radius: Theme.radius
            color: root.highlighted ? Theme.accentSoft : Theme.surface
            border.width: input.activeFocus || root.highlighted ? 2 : 1
            border.color: root.errorText.length > 0 ? Theme.danger
                        : input.activeFocus ? Theme.primary
                        : root.highlighted ? Theme.accent
                        : Theme.border
        }

        Text {
            id: suffixText
            visible: root.suffix.length > 0 && !root.isPassword
            anchors.right: parent.right
            anchors.rightMargin: input.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            text: root.suffix
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
        }

        Text {
            id: revealToggle
            visible: root.isPassword
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root._revealed ? qsTr("Hide") : qsTr("Show")
            color: Theme.primary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root._revealed = !root._revealed
            }
        }
    }

    Label {
        visible: text.length > 0
        text: root.errorText
        color: Theme.danger
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}
