pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

// Navigation entry. compact: false -> sidebar row, true -> bottom tab bar item
AbstractButton {
    id: control

    property bool current: false
    property bool compact: false
    property int compactFontSize: Theme.fontSmall

    // Round counts shown on the item, each with its own color:
    //   [ { count: 2, tone: "primary", label: "requests" }, { count: 1, tone: "danger", label: "expired" } ]
    // tone: "primary" | "danger". Entries with count 0 are hidden.
    property var badges: []

    readonly property var shownBadges: badges.filter(b => b && b.count > 0)

    hoverEnabled: true
    implicitHeight: compact ? 56 : 40
    implicitWidth: compact ? 72 : 200
    leftPadding: compact ? 4 : 14
    rightPadding: compact ? 4 : (shownBadges.length > 0 ? 14 + badgeRow.width + 8 : 14)

    Accessible.name: shownBadges.length > 0
                     ? text + ", " + shownBadges.map(b => b.count + " " + (b.label || "")).join(", ")
                     : text

    contentItem: Label {
        text: control.text
        font.pixelSize: control.compact ? control.compactFontSize : Theme.fontBody
        font.weight: control.current ? Font.DemiBold : Font.Normal
        color: control.current ? Theme.primary
             : control.hovered ? Theme.text
             : Theme.textMuted
        horizontalAlignment: control.compact ? Text.AlignHCenter : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radius
        color: control.compact ? "transparent"
             : control.current ? Theme.primarySoft
             : control.hovered ? Theme.surfaceAlt
             : "transparent"

        // Active indicator for the tab bar
        Rectangle {
            visible: control.compact && control.current
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28
            height: 3
            radius: 2
            color: Theme.primary
        }
    }

    // Counts: right side of the row in the sidebar, above the label in the tab bar
    Row {
        id: badgeRow
        visible: control.shownBadges.length > 0
        spacing: 4
        x: control.compact ? Math.min(control.width / 2 + 6, control.width - width - 2) : control.width - width - 12
        y: control.compact ? 6 : (control.height - height) / 2
        z: 2

        Repeater {
            model: control.shownBadges

            Rectangle {
                id: bubble
                required property var modelData
                readonly property bool danger: modelData.tone === "danger"

                width: Math.max(height, countText.implicitWidth + 10)
                height: 18
                radius: height / 2
                color: danger ? Theme.danger : Theme.primary

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: bubble.modelData.count > 99 ? "99+" : bubble.modelData.count
                    color: bubble.danger ? (Theme.dark ? "#2A0906" : "#FFFFFF") : Theme.textOnPrimary
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
