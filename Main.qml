import QtQuick
import QtQuick.Controls.Basic

// App root. Picks what to show from the session state:
//   resuming the saved login -> a splash (the logo)
//   logged out -> AuthFlow (welcome / log in / sign up)
//   coach      -> CoachHome
//   client     -> ClientHome
ApplicationWindow {
    id: window

    // 1920×1080 by default, shrunk to fit smaller screens
    width: Math.min(1920, Screen.desktopAvailableWidth)
    height: Math.min(1080, Screen.desktopAvailableHeight)
    minimumWidth: 360
    minimumHeight: 560
    visible: true
    title: "Aura"
    color: Theme.background

    // Default colors for controls that don't set their own
    palette {
        window: Theme.background
        windowText: Theme.text
        base: Theme.surface
        text: Theme.text
        button: Theme.surface
        buttonText: Theme.text
        highlight: Theme.primary
        highlightedText: Theme.textOnPrimary
        placeholderText: Theme.textMuted
        mid: Theme.border
        dark: Theme.textMuted
    }

    Loader {
        id: router
        anchors.fill: parent
        sourceComponent: Session.restoring ? splash
                       : !Session.loggedIn ? authFlow
                       : Session.isCoach ? coachApp
                       : clientApp
        onLoaded: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: router.item
        property: "opacity"
        from: 0
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    Component {
        id: splash
        Item {
            BrandMark {
                anchors.centerIn: parent
                size: 64
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.4; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    Component {
        id: authFlow
        AuthFlow {}
    }
    Component {
        id: coachApp
        CoachHome {}
    }
    Component {
        id: clientApp
        ClientHome {}
    }

    // Errors from the C++ stores (a refused change, no connection, ...)
    Toast {
        id: errorToast
    }
    Connections {
        target: ProgramStore
        function onErrorOccurred(message) {
            errorToast.show(message)
        }
    }
    Connections {
        target: ClientStore
        function onErrorOccurred(message) {
            errorToast.show(message)
        }
    }
    Connections {
        target: CoachStore
        function onErrorOccurred(message) {
            errorToast.show(message)
        }
    }
}
