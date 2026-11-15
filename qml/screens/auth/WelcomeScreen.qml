import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// First screen when logged out: log in, or start signing up as coach or client.
AuthPage {
    id: page

    signal loginRequested()
    signal signupRequested(string role)

    title: qsTr("Welcome to Aura")
    subtitle: qsTr("Sessions, plans, progress and messages: one place for coaches and their clients.")

    AuraButton {
        text: qsTr("Log in")
        Layout.fillWidth: true
        onClicked: page.loginRequested()
    }

    RowLayout {
        spacing: 12
        Layout.fillWidth: true
        Layout.topMargin: 12

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        Label {
            text: qsTr("New to Aura? Sign up as")
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
    }

    RoleCard {
        Layout.fillWidth: true
        showArrow: true
        title: qsTr("Coach")
        description: qsTr("Manage your clients, schedule sessions and build programs.")
        onClicked: page.signupRequested("coach")
    }

    RoleCard {
        Layout.fillWidth: true
        showArrow: true
        title: qsTr("Client")
        description: qsTr("Follow your plan, see your sessions and track progress with your coach.")
        onClicked: page.signupRequested("client")
    }
}
