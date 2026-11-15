import QtQuick
import QtQuick.Controls.Basic

// Small status pill. tone: "neutral" | "primary" | "accent" | "danger"
Rectangle {
    id: root

    property alias text: label.text
    property string tone: "neutral"

    implicitHeight: 24
    implicitWidth: label.implicitWidth + 20
    radius: height / 2
    color: Theme.toneSoftColor(tone)

    Label {
        id: label
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
        color: Theme.toneColor(root.tone)
    }
}
