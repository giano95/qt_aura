pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

// Navigation between the logged-out screens: Welcome -> Log in / Sign up.
// When Session.user is set, Main.qml swaps this whole flow for the right home.
StackView {
    id: stack

    initialItem: welcomeComponent

    Component {
        id: welcomeComponent
        WelcomeScreen {
            onLoginRequested: stack.push(loginComponent)
            onSignupRequested: role => stack.push(signupComponent, { role: role })
        }
    }

    Component {
        id: loginComponent
        LoginScreen {
            onBackRequested: stack.pop()
            onSignupRequested: stack.replace(signupComponent)
        }
    }

    Component {
        id: signupComponent
        SignupScreen {
            onBackRequested: stack.pop()
            onLoginRequested: stack.replace(loginComponent)
        }
    }

    pushEnter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "x"; from: 24; to: 0; duration: 240; easing.type: Easing.OutCubic }
        }
    }
    pushExit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
    }
    popEnter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "x"; from: -24; to: 0; duration: 240; easing.type: Easing.OutCubic }
        }
    }
    popExit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
    }
    replaceEnter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
    }
    replaceExit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
    }
}
