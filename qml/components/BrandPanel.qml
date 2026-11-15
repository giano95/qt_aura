pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Left-hand brand panel on the auth screens (desktop width only).
Rectangle {
    id: panel

    clip: true
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.brandTop }
        GradientStop { position: 1.0; color: Theme.brandBottom }
    }

    // Concentric "aura" rings
    Repeater {
        model: 5
        Rectangle {
            id: ring
            required property int index
            readonly property real diameter: panel.height * (0.45 + ring.index * 0.3)
            width: diameter
            height: diameter
            radius: diameter / 2
            x: panel.width * 0.85 - diameter / 2
            y: panel.height * 0.9 - diameter / 2
            color: ring.index === 0 ? "#FFFFFF" : "transparent"
            border.width: 1.5
            border.color: "#FFFFFF"
            opacity: ring.index === 0 ? 0.06 : 0.18 - ring.index * 0.03
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 48
        spacing: 12

        BrandMark { size: 34; color: "#FFFFFF" }
        Label {
            text: "Aura"
            color: "#FFFFFF"
            font.pixelSize: 26
            font.weight: Font.Bold
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 48
        spacing: 14

        Label {
            text: qsTr("The calm workspace for coaches and the people they coach.")
            color: "#FFFFFF"
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            lineHeight: 1.1
            Layout.fillWidth: true
            Layout.maximumWidth: 460
            Layout.bottomMargin: 10
        }

        Repeater {
            model: [
                qsTr("Clients, sessions and programs in one place"),
                qsTr("Progress your clients can actually see"),
                qsTr("Check-ins and messages without the chat chaos")
            ]
            RowLayout {
                id: point
                required property string modelData
                spacing: 12
                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: "#FFFFFF"
                    opacity: 0.8
                }
                Label {
                    text: point.modelData
                    color: "#FFFFFF"
                    opacity: 0.85
                    font.pixelSize: Theme.fontLarge
                }
            }
        }
    }
}
