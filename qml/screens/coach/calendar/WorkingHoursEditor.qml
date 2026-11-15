pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// The coach's standard weekly availability: for each weekday, on/off and one or
// more time ranges (e.g. 9:00–13:00 and 14:00–18:00 for a lunch break).
// Edits a draft; nothing changes in the calendar until save() succeeds.
// Shown inside WorkingHoursDialog, which owns the Cancel / Save buttons.
ColumnLayout {
    id: root

    property bool wide: true

    property var draft: CalendarStore.cloneHours()
    property int revision: 0          // bumped on in-place time edits
    property bool dirty: false
    property var problems: ({})       // day -> message, filled on save

    // Monday first
    readonly property var dayOrder: [1, 2, 3, 4, 5, 6, 0]
    readonly property double totalMinutes: CalendarStore.totalWeeklyMinutes(draft, revision)


    function dayName(day) {
        return Qt.locale().dayName(day, Locale.LongFormat)
    }

    function ranges(day) {
        return draft[String(day)] || []
    }

    // `revision` is unused: passing it makes bindings refresh after in-place edits
    function rangeValue(day, index, key, revision) {
        const r = ranges(day)[index]
        return r ? r[key] : 0
    }

    // Structural change: replaces the draft (rebuilds the rows)
    function update(mutate) {
        const copy = JSON.parse(JSON.stringify(draft))
        mutate(copy)
        draft = copy
        dirty = true
        problems = ({})
    }

    // Time change: in place, so the stepper being held isn't rebuilt
    function setTime(day, index, key, minutes) {
        draft[String(day)][index][key] = minutes
        revision += 1
        dirty = true
        problems = ({})
    }

    function setDayEnabled(day, enabled) {
        update(h => h[String(day)] = enabled ? [{ start: 9 * 60, end: 18 * 60 }] : [])
    }

    function canAddRange(day) {
        const list = ranges(day)
        return list.length > 0 && list[list.length - 1].end + 90 <= 24 * 60
    }

    // Adds a range one hour after the last one (two hours long, or what fits)
    function addRange(day) {
        update(h => {
            const list = h[String(day)]
            const start = list[list.length - 1].end + 60
            list.push({ start: start, end: Math.min(start + 120, 24 * 60) })
        })
    }

    function removeRange(day, index) {
        update(h => h[String(day)].splice(index, 1))
    }

    function copyMondayToWeekdays() {
        update(h => {
            for (let d = 2; d <= 5; ++d)
                h[String(d)] = JSON.parse(JSON.stringify(h["1"]))
        })
    }

    // Starts over from the saved working hours
    function reset() {
        draft = CalendarStore.cloneHours()
        dirty = false
        problems = ({})
    }

    // Saves the draft; returns false (and shows the problems) if a day is invalid
    function save() {
        const found = {}
        for (let d = 0; d < 7; ++d) {
            const problem = CalendarStore.rangeProblem(ranges(d))
            if (problem)
                found[d] = problem
        }
        problems = found
        if (Object.keys(found).length > 0)
            return false
        CalendarStore.saveWeeklyHours(draft)
        reset()
        return true
    }

    spacing: 16

    ColumnLayout {
        spacing: 12
        Layout.fillWidth: true

        Label {
            text: qsTr("When you're normally available for sessions. Clients will be able to book inside these hours. To take a single slot or day off, block it in the calendar instead.")
            color: Theme.textMuted
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Repeater {
            model: root.dayOrder

            ColumnLayout {
                id: dayRow
                required property int modelData
                required property int index
                readonly property int day: modelData
                readonly property bool enabledDay: root.ranges(day).length > 0
                readonly property int rangeCount: root.ranges(day).length

                spacing: 8
                Layout.fillWidth: true

                Rectangle {
                    visible: dayRow.index > 0
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    columns: root.wide ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 10

                    // Day name + switch
                    RowLayout {
                        spacing: 12
                        Layout.preferredWidth: root.wide ? 180 : -1
                        Layout.fillWidth: !root.wide
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: root.wide ? 5 : 0

                        AuraSwitch {
                            checked: dayRow.enabledDay
                            onToggled: root.setDayEnabled(dayRow.day, checked)
                        }
                        Label {
                            text: root.dayName(dayRow.day)
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }

                    // Ranges
                    ColumnLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Label {
                            visible: !dayRow.enabledDay
                            text: qsTr("Not available")
                            color: Theme.textMuted
                            Layout.topMargin: root.wide ? 6 : 0
                        }

                        Repeater {
                            model: dayRow.rangeCount

                            RowLayout {
                                id: rangeRow
                                required property int index
                                spacing: root.wide ? 8 : 2

                                TimeStepper {
                                    compact: !root.wide
                                    value: root.rangeValue(dayRow.day, rangeRow.index, "start", root.revision)
                                    maximum: root.rangeValue(dayRow.day, rangeRow.index, "end", root.revision) - 30
                                    onEdited: minutes => root.setTime(dayRow.day, rangeRow.index, "start", minutes)
                                }
                                Label {
                                    text: qsTr("to")
                                    color: Theme.textMuted
                                    Layout.leftMargin: 4
                                    Layout.rightMargin: 4
                                }
                                TimeStepper {
                                    compact: !root.wide
                                    value: root.rangeValue(dayRow.day, rangeRow.index, "end", root.revision)
                                    minimum: root.rangeValue(dayRow.day, rangeRow.index, "start", root.revision) + 30
                                    onEdited: minutes => root.setTime(dayRow.day, rangeRow.index, "end", minutes)
                                }
                                IconButton {
                                    implicitWidth: root.wide ? 32 : 26
                                    visible: dayRow.rangeCount > 1
                                    glyph: "✕"
                                    tooltip: qsTr("Remove these hours")
                                    destructive: true
                                    onClicked: root.removeRange(dayRow.day, rangeRow.index)
                                }
                            }
                        }

                        AuraButton {
                            visible: dayRow.enabledDay
                            enabled: root.canAddRange(dayRow.day)
                            variant: "ghost"
                            text: qsTr("+ Add hours (e.g. after a break)")
                            implicitHeight: 32
                            leftPadding: 4
                            font.pixelSize: Theme.fontSmall + 1
                            onClicked: root.addRange(dayRow.day)
                        }

                        Label {
                            visible: text.length > 0
                            text: root.problems[dayRow.day] || ""
                            color: Theme.danger
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }
        }
    }

    // Shortcut and weekly total
    Flow {
        Layout.fillWidth: true
        spacing: 8

        AuraButton {
            variant: "secondary"
            text: qsTr("Copy Monday to Tue–Fri")
            onClicked: root.copyMondayToWeekdays()
        }
        Label {
            height: 44
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            text: qsTr("%1 a week").arg(CalendarStore.hoursText(root.totalMinutes / 60))
            color: Theme.textMuted
        }
    }
}
