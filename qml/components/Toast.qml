import QtQuick
import QtQuick.Controls.Basic

// Short confirmation message at the bottom of its parent. Call show("...").
Rectangle {
    id: toast

    function show(message) {
        label.text = message
        hideTimer.restart()
        opacity = 1
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    z: 100
    implicitWidth: label.implicitWidth + 40
    implicitHeight: 44
    radius: height / 2
    color: Theme.dark ? "#EBEFED" : "#1E2421"
    opacity: 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Label {
        id: label
        anchors.centerIn: parent
        color: Theme.dark ? "#111513" : "#FFFFFF"
        font.pixelSize: Theme.fontBody
        font.weight: Font.DemiBold
    }

    Timer {
        id: hideTimer
        interval: 2200
        onTriggered: toast.opacity = 0
    }
}
