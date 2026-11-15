import QtQuick

// Thin horizontal progress bar. value is 0..1
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.primary
    property real shownValue: Math.min(1, Math.max(0, value))

    Behavior on shownValue {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    implicitHeight: 8
    implicitWidth: 120
    radius: height / 2
    color: Theme.surfaceAlt

    Rectangle {
        width: Math.max(root.height, root.width * root.shownValue)
        height: parent.height
        radius: parent.radius
        color: root.fillColor
        visible: root.value > 0
    }
}
