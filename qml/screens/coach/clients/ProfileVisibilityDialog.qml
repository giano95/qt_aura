import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Public or private coach profile. Decides how new clients join:
//   public  -> listed in the directory, clients send requests you accept
//   private -> not listed, you invite clients by email
AuraDialog {
    id: dialog

    property string choice: "public"

    readonly property int pendingCount: CoachStore.pendingRequests.length
    readonly property bool changed: choice !== (CoachStore.isPublic ? "public" : "private")

    signal saved(string visibility)

    function openEditor() {
        choice = CoachStore.isPublic ? "public" : "private"
        open()
    }

    title: qsTr("Profile visibility")
    preferredWidth: 560

    Label {
        text: qsTr("Choose how new clients find you.")
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    RoleCard {
        Layout.fillWidth: true
        title: qsTr("Public")
        description: qsTr("You're listed in the coach directory. Anyone can send you a request, and you choose who to accept.")
        selected: dialog.choice === "public"
        onClicked: dialog.choice = "public"
    }

    RoleCard {
        Layout.fillWidth: true
        title: qsTr("Private")
        description: qsTr("You're not listed. Only people you invite by email can become your clients.")
        selected: dialog.choice === "private"
        onClicked: dialog.choice = "private"
    }

    Notice {
        tone: "danger"
        visible: dialog.choice === "private" && dialog.changed && dialog.pendingCount > 0
        Layout.fillWidth: true
        text: dialog.pendingCount === 1
              ? qsTr("You have 1 request waiting. It will be declined.")
              : qsTr("You have %1 requests waiting. They will be declined.").arg(dialog.pendingCount)
    }

    Notice {
        tone: "info"
        Layout.fillWidth: true
        text: qsTr("Your current clients aren't affected either way.")
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Save")
            enabled: dialog.changed
            onClicked: {
                CoachStore.setVisibility(dialog.choice)
                dialog.close()
                dialog.saved(dialog.choice)
            }
        }
    ]
}
