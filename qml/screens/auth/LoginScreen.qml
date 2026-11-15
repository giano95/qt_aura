import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Log in with email and password. The account's role decides which home opens.
AuthPage {
    id: page

    signal signupRequested()

    showBack: true
    title: qsTr("Log in")
    subtitle: qsTr("Welcome back. Enter your details to continue.")

    // Field errors appear only after the first submit attempt
    property bool submitted: false
    readonly property string emailError: {
        if (!submitted)
            return ""
        if (emailField.text.trim().length === 0)
            return qsTr("Enter your email.")
        if (!Session.isValidEmail(emailField.text))
            return qsTr("Enter a valid email address.")
        return ""
    }
    readonly property string passwordError:
        submitted && passwordField.text.length === 0 ? qsTr("Enter your password.") : ""

    function submit() {
        submitted = true
        if (emailError || passwordError)
            return
        Session.login(emailField.text, passwordField.text)
    }

    Component.onCompleted: Session.clearError()
    StackView.onActivated: emailField.focusInput()

    Notice {
        text: Session.lastError
        Layout.fillWidth: true
    }

    AuraTextField {
        id: emailField
        Layout.fillWidth: true
        label: qsTr("Email")
        placeholderText: "name@example.com"
        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
        errorText: page.emailError
        onAccepted: passwordField.focusInput()
    }

    AuraTextField {
        id: passwordField
        Layout.fillWidth: true
        label: qsTr("Password")
        isPassword: true
        errorText: page.passwordError
        onAccepted: page.submit()
    }

    AuraButton {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Log in")
        busy: Session.busy
        busyText: qsTr("Logging in…")
        onClicked: page.submit()
    }

    RowLayout {
        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        Label {
            text: qsTr("Don't have an account?")
            color: Theme.textMuted
        }
        AuraButton {
            variant: "ghost"
            text: qsTr("Sign up")
            leftPadding: 6
            rightPadding: 6
            onClicked: page.signupRequested()
        }
    }

    Notice {
        tone: "info"
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("<b>Prototype demo accounts</b><br>Coach: coach@aura.app<br>Client: client@aura.app<br>Password for both: password")
    }
}
