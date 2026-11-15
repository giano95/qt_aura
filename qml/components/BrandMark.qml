import QtQuick

// The Aura logo: a dot with two fading rings around it.
Item {
    id: root

    property int size: 28
    property color color: Theme.primary

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, Math.round(root.size * 0.08))
        border.color: root.color
        opacity: 0.35
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(root.size * 0.64)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, Math.round(root.size * 0.08))
        border.color: root.color
        opacity: 0.65
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(root.size * 0.3)
        height: width
        radius: width / 2
        color: root.color
    }
}
