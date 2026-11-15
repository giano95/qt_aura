import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// "Are you sure?" dialog.
AuraDialog {
    id: dialog

    property string message: ""
    property string confirmText: qsTr("Confirm")
    property string cancelText: qsTr("Cancel")
    property bool destructive: false

    signal confirmed()

    preferredWidth: 440

    Label {
        text: dialog.message
        color: Theme.textMuted
        font.pixelSize: Theme.fontBody
        wrapMode: Text.Wrap
        lineHeight: 1.2
        Layout.fillWidth: true
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: dialog.cancelText
            onClicked: dialog.close()
        },
        AuraButton {
            variant: dialog.destructive ? "danger" : "primary"
            text: dialog.confirmText
            onClicked: {
                dialog.close()
                dialog.confirmed()
            }
        }
    ]
}
