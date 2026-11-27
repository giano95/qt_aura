import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Box to write a message. On desktop Enter sends and Shift+Enter starts a new
// line; on phones Enter is a new line and the button sends.
RowLayout {
    id: composer

    property alias text: area.text
    readonly property bool enterSends: Qt.platform.os !== "android" && Qt.platform.os !== "ios"

    signal sendRequested(string text)

    function send() {
        if (area.text.trim().length === 0)
            return
        composer.sendRequested(area.text)
        area.text = ""
        area.forceActiveFocus()
    }

    function focusInput() {
        area.forceActiveFocus()
    }

    spacing: 8

    ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(44, area.implicitHeight), 140)

        TextArea {
            id: area
            placeholderText: qsTr("Write a message…")
            wrapMode: TextArea.Wrap
            padding: 11
            leftPadding: 14
            rightPadding: 14
            color: Theme.text
            placeholderTextColor: Theme.textMuted
            selectionColor: Theme.primary
            selectedTextColor: Theme.textOnPrimary
            font.pixelSize: Theme.fontBody
            selectByMouse: true

            Keys.onReturnPressed: event => composer.handleEnter(event)
            Keys.onEnterPressed: event => composer.handleEnter(event)

            background: Rectangle {
                radius: 22
                color: Theme.surface
                border.width: area.activeFocus ? 2 : 1
                border.color: area.activeFocus ? Theme.primary : Theme.border
            }
        }
    }

    AuraButton {
        text: qsTr("Send")
        enabled: area.text.trim().length > 0
        Layout.alignment: Qt.AlignBottom
        onClicked: composer.send()
    }

    function handleEnter(event) {
        if (!enterSends || (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = false     // the text area adds a new line
            return
        }
        event.accepted = true
        send()
    }
}
