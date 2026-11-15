import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Invite a new client by email.
AuraDialog {
    id: dialog

    property bool submitted: false

    readonly property string nameError:
        submitted && nameField.text.trim().length < 2 ? qsTr("Enter the client's name.") : ""
    readonly property string emailError: {
        if (!submitted)
            return ""
        if (!Session.isValidEmail(emailField.text))
            return qsTr("Enter a valid email address.")
        if (ClientStore.isEmailTaken(emailField.text))
            return qsTr("This person is already one of your clients.")
        return ""
    }

    signal invited(int clientId)

    function openNew() {
        nameField.text = ""
        emailField.text = ""
        goalField.text = ""
        submitted = false
        open()
    }

    function invite() {
        submitted = true
        if (nameError || emailError)
            return
        const id = ClientStore.invite(nameField.text, emailField.text, goalField.text)
        close()
        invited(id)
    }

    title: qsTr("Invite a client")
    preferredWidth: 500
    onOpened: nameField.focusInput()

    Label {
        text: qsTr("They'll get an email to create a client account linked to you. You can assign a program right away; they'll see it once they join.")
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    AuraTextField {
        id: nameField
        Layout.fillWidth: true
        label: qsTr("Full name")
        errorText: dialog.nameError
        onAccepted: emailField.focusInput()
    }

    AuraTextField {
        id: emailField
        Layout.fillWidth: true
        label: qsTr("Email")
        placeholderText: "name@example.com"
        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
        errorText: dialog.emailError
        onAccepted: goalField.focusInput()
    }

    AuraTextField {
        id: goalField
        Layout.fillWidth: true
        label: qsTr("Main goal (optional)")
        placeholderText: qsTr("e.g. Run a 10 km, lose 5 kg, fix back pain")
        onAccepted: dialog.invite()
    }

    Notice {
        tone: "info"
        Layout.fillWidth: true
        text: qsTr("Prototype: no email is actually sent.")
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Send invite")
            onClicked: dialog.invite()
        }
    ]
}
