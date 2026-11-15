import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Modal dialog with a title and a footer row of buttons.
// Put buttons in `actions`; they are right-aligned. Put anything that should
// sit on the left (e.g. a destructive action) in `leftActions`.
Dialog {
    id: dialog

    property int preferredWidth: 520
    default property alias body: bodyColumn.data
    property alias actions: actionRow.data
    property alias leftActions: leftActionRow.data
    property bool scrollable: true

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    width: Math.min(preferredWidth, parent ? parent.width - 32 : preferredWidth)
    height: Math.min(implicitHeight, parent ? parent.height - 48 : implicitHeight)
    padding: 24
    topPadding: title.length > 0 ? 4 : 24       // no header when there's no title
    bottomPadding: 8

    header: Label {
        visible: text.length > 0
        text: dialog.title
        font.pixelSize: Theme.fontTitle
        font.weight: Font.Bold
        elide: Text.ElideRight
        padding: visible ? 24 : 0
        bottomPadding: visible ? 12 : 0
    }

    contentItem: Flickable {
        id: flick
        clip: true
        interactive: dialog.scrollable && contentHeight > height
        contentWidth: width
        contentHeight: bodyColumn.implicitHeight
        implicitHeight: bodyColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: flick.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: bodyColumn
            width: flick.width
            spacing: 16
        }
    }

    footer: Item {
        implicitHeight: footerRow.implicitHeight + 40
        RowLayout {
            id: footerRow
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 16
            anchors.bottomMargin: 24
            spacing: 8

            RowLayout {
                id: leftActionRow
                spacing: 8
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                id: actionRow
                spacing: 8
            }
        }
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusLarge
        border.width: 1
        border.color: Theme.border
    }

    Overlay.modal: Rectangle {
        color: Theme.dark ? "#B3000000" : "#66101412"
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
    }
}
