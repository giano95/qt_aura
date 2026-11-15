import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Time of day picker: − 09:00 +, in `step`-minute steps. Hold a button to
// keep stepping. The parent owns the value: bind `value`, handle `edited`.
RowLayout {
    id: root

    property int value: 540          // minutes from midnight
    property int minimum: 0
    property int maximum: 24 * 60
    property int step: 30
    property bool compact: false     // narrower, for phones

    signal edited(int value)

    spacing: 2

    IconButton {
        implicitWidth: root.compact ? 26 : 32
        glyph: "−"
        tooltip: qsTr("Earlier")
        autoRepeat: true
        enabled: root.value - root.step >= root.minimum
        onClicked: root.edited(Math.max(root.minimum, root.value - root.step))
    }

    Rectangle {
        implicitWidth: root.compact ? 54 : 64
        implicitHeight: 34
        radius: 8
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Label {
            anchors.centerIn: parent
            text: root.value >= 24 * 60 ? "24:00" : CalendarStore.formatMinutes(root.value)
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    IconButton {
        implicitWidth: root.compact ? 26 : 32
        glyph: "+"
        tooltip: qsTr("Later")
        autoRepeat: true
        enabled: root.value + root.step <= root.maximum
        onClicked: root.edited(Math.min(root.maximum, root.value + root.step))
    }
}
