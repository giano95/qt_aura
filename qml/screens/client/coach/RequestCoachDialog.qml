import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Send a coaching request: your goal and an optional message.
AuraDialog {
    id: dialog

    property int coachId: 0
    property bool submitted: false

    readonly property var coach: CoachStore.coachById(coachId)
    readonly property string firstName: coach ? coach.name.split(" ")[0] : ""
    readonly property string goalError:
        submitted && goalField.text.trim().length < 3 ? qsTr("Tell %1 what you'd like to achieve.").arg(firstName) : ""

    signal sent()

    function openFor(id) {
        coachId = id
        goalField.text = ""
        messageField.text = ""
        submitted = false
        open()
    }

    function send() {
        submitted = true
        if (goalError)
            return
        CoachStore.request(coachId, goalField.text, messageField.text)
        close()
        sent()
    }

    title: qsTr("Request %1 as your coach").arg(firstName)
    preferredWidth: 540
    onOpened: goalField.focusInput()

    Label {
        text: qsTr("%1 will see your request and reply. Once they accept, they'll set up your program and sessions.").arg(dialog.firstName)
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    AuraTextField {
        id: goalField
        Layout.fillWidth: true
        label: qsTr("Your main goal")
        placeholderText: qsTr("e.g. Get stronger, lose 5 kg, run a 10 km")
        errorText: dialog.goalError
    }

    AuraTextArea {
        id: messageField
        Layout.fillWidth: true
        label: qsTr("Message (optional)")
        placeholderText: qsTr("Experience, injuries, when you can train…")
        minimumHeight: 80
    }

    Notice {
        tone: "info"
        Layout.fillWidth: true
        text: qsTr("Prototype: the coach accepts automatically after a few seconds.")
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Send request")
            onClicked: dialog.send()
        }
    ]
}
