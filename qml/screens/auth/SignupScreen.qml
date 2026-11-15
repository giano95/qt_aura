import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Create a coach or client account. `role` can be preselected by the caller.
AuthPage {
    id: page

    signal loginRequested()

    property string role: ""        // "coach" | "client" | "" (not chosen yet)

    showBack: true
    title: qsTr("Create your account")
    subtitle: qsTr("Choose the type of account, then fill in your details.")

    // Field errors appear only after the first submit attempt
    property bool submitted: false
    readonly property string roleError:
        submitted && role === "" ? qsTr("Choose an account type.") : ""
    readonly property string nameError:
        submitted && nameField.text.trim().length < 2 ? qsTr("Enter your full name.") : ""
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
        submitted && passwordField.text.length < 8 ? qsTr("Use at least 8 characters.") : ""
    readonly property string confirmError:
        submitted && confirmField.text !== passwordField.text ? qsTr("Passwords don't match.") : ""

    function submit() {
        submitted = true
        if (roleError || nameError || emailError || passwordError || confirmError)
            return
        Session.signup(nameField.text, emailField.text, passwordField.text, role)
    }

    Component.onCompleted: Session.clearError()
    StackView.onActivated: {
        if (role !== "")
            nameField.focusInput()
    }

    // ---- account type ----

    ColumnLayout {
        spacing: 10
        Layout.fillWidth: true

        Label {
            text: qsTr("Account type")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        RoleCard {
            Layout.fillWidth: true
            title: qsTr("Coach")
            description: qsTr("I work with clients and want to manage sessions, programs and progress.")
            selected: page.role === "coach"
            onClicked: page.role = "coach"
        }

        RoleCard {
            Layout.fillWidth: true
            title: qsTr("Client")
            description: qsTr("I'm working with a coach and want to follow my plan and progress.")
            selected: page.role === "client"
            onClicked: page.role = "client"
        }

        Label {
            visible: text.length > 0
            text: page.roleError
            color: Theme.danger
            font.pixelSize: Theme.fontSmall
        }
    }

    // ---- details ----

    Notice {
        text: Session.lastError
        Layout.fillWidth: true
    }

    AuraTextField {
        id: nameField
        Layout.fillWidth: true
        label: qsTr("Full name")
        placeholderText: qsTr("First and last name")
        errorText: page.nameError
        onAccepted: emailField.focusInput()
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
        placeholderText: qsTr("At least 8 characters")
        isPassword: true
        errorText: page.passwordError
        onAccepted: confirmField.focusInput()
    }

    AuraTextField {
        id: confirmField
        Layout.fillWidth: true
        label: qsTr("Confirm password")
        isPassword: true
        errorText: page.confirmError
        onAccepted: page.submit()
    }

    AuraButton {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: page.role === "coach" ? qsTr("Create coach account")
            : page.role === "client" ? qsTr("Create client account")
            : qsTr("Create account")
        busy: Session.busy
        busyText: qsTr("Creating account…")
        onClicked: page.submit()
    }

    RowLayout {
        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        Label {
            text: qsTr("Already have an account?")
            color: Theme.textMuted
        }
        AuraButton {
            variant: "ghost"
            text: qsTr("Log in")
            leftPadding: 6
            rightPadding: 6
            onClicked: page.loginRequested()
        }
    }
}
