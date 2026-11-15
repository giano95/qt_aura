import QtQuick
import QtQuick.Controls.Basic

// Inline message box. tone: "danger" | "info". Hidden while text is empty.
Rectangle {
    id: root

    property alias text: label.text
    property string tone: "danger"

    visible: text.length > 0
    implicitWidth: 240
    implicitHeight: label.implicitHeight + 24
    radius: Theme.radius
    color: tone === "danger" ? Theme.dangerSoft : Theme.surfaceAlt

    Label {
        id: label
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 12
        wrapMode: Text.Wrap
        textFormat: Text.StyledText
        font.pixelSize: Theme.fontSmall + 1
        color: root.tone === "danger" ? Theme.danger : Theme.textMuted
    }
}
