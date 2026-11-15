import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Edit the coach's weekly working hours. Same pattern as InviteClientDialog:
// opened from a button in the page header, Cancel / Save in the footer.
// Cancel (or closing the dialog) throws away unsaved changes.
AuraDialog {
    id: dialog

    signal saved()

    function openEditor() {
        editor.reset()
        open()
    }

    function save() {
        if (!editor.save())
            return
        close()
        saved()
    }

    title: qsTr("Working hours")
    preferredWidth: 760

    WorkingHoursEditor {
        id: editor
        wide: dialog.availableWidth >= 600
        Layout.fillWidth: true
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Save working hours")
            enabled: editor.dirty
            onClicked: dialog.save()
        }
    ]
}
