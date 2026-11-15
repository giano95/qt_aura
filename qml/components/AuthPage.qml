import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Layout shared by the welcome, login and signup screens.
//  - wide window: brand panel on the left, form on the right
//  - narrow window: form only, with a small logo on top
// Children are placed in the form column.
Item {
    id: page

    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    default property alias formContent: form.data

    readonly property bool wide: width >= 860

    signal backRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        BrandPanel {
            visible: page.wide
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(page.width * 0.44)
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, column.implicitHeight + 112)
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: column
                width: Math.min(420, flick.width - 32)
                x: (flick.width - width) / 2
                y: (flick.contentHeight - implicitHeight) / 2
                spacing: 8

                AuraButton {
                    visible: page.showBack
                    variant: "ghost"
                    text: qsTr("← Back")
                    leftPadding: 8
                    rightPadding: 12
                    Layout.leftMargin: -8
                    Layout.bottomMargin: 8
                    onClicked: page.backRequested()
                }

                RowLayout {
                    visible: !page.wide
                    spacing: 10
                    Layout.bottomMargin: 16

                    BrandMark { size: 32 }
                    Label {
                        text: "Aura"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                }

                Label {
                    text: page.title
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    visible: text.length > 0
                    text: page.subtitle
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontLarge
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.bottomMargin: 20
                }

                ColumnLayout {
                    id: form
                    spacing: 16
                    Layout.fillWidth: true
                }
            }
        }
    }

    AuraButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        variant: "ghost"
        text: Theme.dark ? qsTr("Light mode") : qsTr("Dark mode")
        onClicked: Theme.dark = !Theme.dark
    }
}
