import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Full profile of a coach from the directory, with the button to request them.
AuraDialog {
    id: dialog

    property string coachId: ""
    property bool canRequest: true          // false when viewing a pending request

    readonly property var coach: CoachStore.coachById(coachId, CoachStore.revision)

    signal requestRequested(string coachId)

    function openFor(id, allowRequest) {
        coachId = id
        canRequest = allowRequest !== false
        open()
    }

    title: ""
    preferredWidth: 620

    CoachProfile {
        coach: dialog.coach
        Layout.fillWidth: true
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Close")
            onClicked: dialog.close()
        },
        AuraButton {
            visible: dialog.canRequest
            enabled: dialog.coach !== null && dialog.coach.accepting
            text: dialog.coach ? qsTr("Request %1 as my coach").arg(dialog.coach.name.split(" ")[0]) : ""
            onClicked: {
                dialog.close()
                dialog.requestRequested(dialog.coachId)
            }
        }
    ]
}
