pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

// Programs area of the coach app: the program list with the program editor
// pushed on top. Other sections can open a program with openProgram().
StackView {
    id: stack

    // The editor opened by openProgram() was closed: go back to where it came from
    signal returnRequested()

    // Opens the editor for `programId`. `backText` labels the back button,
    // which then returns to the caller (via returnRequested) instead of the list.
    function openProgram(programId, backText) {
        const editor = currentItem as ProgramEditor     // null while the list is showing
        if (editor && editor.draft.id === programId) {
            editor.backText = backText
            editor.returnOnClose = true
            return
        }
        if (editor) {
            editor.requestSwitch(programId, backText)
            return
        }
        push(editorComponent, { programId: programId, backText: backText, returnOnClose: true }, StackView.Immediate)
    }

    initialItem: homeComponent

    Component {
        id: homeComponent
        ProgramsHome {
            onEditRequested: programId => stack.push(editorComponent, { programId: programId })
        }
    }

    Component {
        id: editorComponent
        ProgramEditor {
            id: editor
            onCloseRequested: {
                const back = editor.returnOnClose
                stack.popCurrentItem(back ? StackView.Immediate : StackView.PopTransition)
                if (back)
                    stack.returnRequested()
            }
            onSwitchRequested: (programId, backText) =>
                stack.replace(editorComponent, { programId: programId, backText: backText, returnOnClose: true }, StackView.Immediate)
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
