pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

// Clients area of the coach app: the client list with a client's detail page
// pushed on top.
StackView {
    id: stack

    signal openProgramRequested(int programId, string clientName)

    initialItem: listComponent

    Component {
        id: listComponent
        ClientsHome {
            onOpenRequested: clientId => stack.push(detailComponent, { clientId: clientId })
        }
    }

    Component {
        id: detailComponent
        ClientDetail {
            onCloseRequested: stack.pop()
            onOpenProgramRequested: (programId, clientName) => stack.openProgramRequested(programId, clientName)
        }
    }

    pushEnter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            NumberAnimation { property: "y"; from: 16; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }
    pushExit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
    }
    popEnter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
    }
    popExit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 }
            NumberAnimation { property: "y"; from: 0; to: 16; duration: 140 }
        }
    }
}
