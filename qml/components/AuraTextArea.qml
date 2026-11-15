import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Labeled multi-line text input that grows with its content.
ColumnLayout {
    id: root

    property alias label: caption.text
    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property int minimumHeight: 88

    signal textEdited()

    spacing: 6

    Label {
        id: caption
        visible: text.length > 0
        color: Theme.text
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
    }

    TextArea {
        id: area
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(root.minimumHeight, implicitHeight)
        padding: 12
        leftPadding: 14
        rightPadding: 14
        wrapMode: TextArea.Wrap
        color: Theme.text
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.fontBody
        selectByMouse: true
        onTextChanged: if (activeFocus) root.textEdited()

        background: Rectangle {
            radius: Theme.radius
            color: Theme.surface
            border.width: area.activeFocus ? 2 : 1
            border.color: area.activeFocus ? Theme.primary : Theme.border
        }
    }
}
