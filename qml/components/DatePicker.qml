pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Month calendar for picking a day. Weeks start on Monday.
// `selectedMs` is midnight (local time) of the chosen day.
ColumnLayout {
    id: root

    property double selectedMs: 0
    property int month: new Date().getMonth()
    property int year: new Date().getFullYear()

    signal picked(double ms)

    // Midnight of the Monday on or before the 1st of the shown month
    readonly property var firstCell: {
        const first = new Date(year, month, 1)
        return new Date(year, month, 1 - (first.getDay() + 6) % 7)
    }
    readonly property double todayMs: {
        const d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    }

    function showMonthOf(ms) {
        const d = new Date(ms)
        month = d.getMonth()
        year = d.getFullYear()
    }

    function step(delta) {
        const d = new Date(year, month + delta, 1)
        month = d.getMonth()
        year = d.getFullYear()
    }

    onSelectedMsChanged: if (selectedMs > 0) showMonthOf(selectedMs)

    spacing: 6

    RowLayout {
        Layout.fillWidth: true

        IconButton {
            glyph: "‹"
            tooltip: qsTr("Previous month")
            onClicked: root.step(-1)
        }
        Label {
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        IconButton {
            glyph: "›"
            tooltip: qsTr("Next month")
            onClicked: root.step(1)
        }
    }

    GridLayout {
        columns: 7
        columnSpacing: 2
        rowSpacing: 2
        Layout.alignment: Qt.AlignHCenter

        Repeater {
            model: 7
            Label {
                required property int index
                // Locale day numbers: 1 = Monday ... 7 = Sunday
                text: Qt.locale().dayName(index + 1 === 7 ? 0 : index + 1, Locale.ShortFormat).slice(0, 2)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 36
            }
        }

        Repeater {
            model: 42

            AbstractButton {
                id: cell
                required property int index
                readonly property var date: new Date(root.firstCell.getFullYear(),
                                                     root.firstCell.getMonth(),
                                                     root.firstCell.getDate() + index)
                readonly property double ms: date.getTime()
                readonly property bool inMonth: date.getMonth() === root.month
                readonly property bool selected: ms === root.selectedMs
                readonly property bool isToday: ms === root.todayMs

                implicitWidth: 36
                implicitHeight: 34
                hoverEnabled: true
                onClicked: {
                    root.selectedMs = cell.ms
                    root.picked(cell.ms)
                }

                contentItem: Text {
                    text: cell.date.getDate()
                    font.pixelSize: Theme.fontBody
                    font.weight: cell.selected || cell.isToday ? Font.DemiBold : Font.Normal
                    color: cell.selected ? Theme.textOnPrimary
                         : cell.inMonth ? Theme.text
                         : Theme.textMuted
                    opacity: cell.inMonth || cell.selected ? 1 : 0.5
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: height / 2
                    color: cell.selected ? Theme.primary
                         : cell.hovered ? Theme.surfaceAlt
                         : "transparent"
                    border.width: cell.isToday && !cell.selected ? 1.5 : 0
                    border.color: Theme.primary
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
