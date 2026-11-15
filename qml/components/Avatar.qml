import QtQuick
import QtQuick.Controls.Basic

// Round avatar with initials. The color is derived from the name so the same
// person always gets the same color.
Rectangle {
    id: root

    property string name: ""
    property int size: 36

    readonly property string initials: name.split(" ")
        .filter(part => part.length > 0)
        .slice(0, 2)
        .map(part => part[0].toUpperCase())
        .join("")
    readonly property var _tones: ["primary", "accent", "neutral"]
    readonly property string _tone: {
        let sum = 0
        for (let i = 0; i < name.length; ++i)
            sum += name.charCodeAt(i)
        return _tones[sum % _tones.length]
    }

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: Theme.toneSoftColor(_tone)

    Label {
        anchors.centerIn: parent
        text: root.initials
        font.pixelSize: Math.round(root.size * 0.38)
        font.weight: Font.DemiBold
        color: root._tone === "neutral" ? Theme.text : Theme.toneColor(root._tone)
    }
}
