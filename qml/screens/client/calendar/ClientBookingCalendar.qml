pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// The coach's week in 30-minute slots, as the client sees it:
//  - free (white): can be booked
//  - unavailable (grey): booked by someone, blocked, or too soon (no details shown)
//  - outside working hours (light)
//  - your own sessions on top: confirmed (green) or requested (amber)
// Click a free slot to choose 30 minutes, drag down or up to choose a longer
// session (it stops at the first slot that isn't free). Narrow screens show
// one day; the length can then be changed with − / + in the bar below.
ColumnLayout {
    id: root

    property string coachId: ""
    property bool wide: true
    property double weekStart: CalendarStore.mondayOf(Date.now())
    property int selectedDay: (new Date().getDay() + 6) % 7      // shown day on narrow screens

    // Current selection (dayIndex is 0..6 within the shown week; -1 = none)
    property int selDay: -1
    property int selFrom: -1
    property int selTo: -1
    property var hover: null

    readonly property bool hasSelection: selDay >= 0 && selTo > selFrom
    readonly property double todayMs: CalendarStore.startOfDay(CalendarStore.now)
    readonly property double firstWeek: CalendarStore.mondayOf(CalendarStore.now)
    readonly property double lastWeek: CalendarStore.addDays(firstWeek, 7 * (CalendarStore.bookingWeeks - 1))
    readonly property var days: [0, 1, 2, 3, 4, 5, 6].map(i => CalendarStore.addDays(weekStart, i))
    readonly property var shownIndexes: wide ? [0, 1, 2, 3, 4, 5, 6] : [selectedDay]
    readonly property var range: CalendarStore.coachVisibleRange(coachId, weekStart, CalendarStore.revision)
    readonly property int slotCount: (range.to - range.from) / CalendarStore.slotMinutes
    readonly property int timeColumnWidth: 52
    readonly property int rowHeight: wide ? 24 : 34
    readonly property string coachFirstName: {
        const c = CoachStore.coachById(coachId, CoachStore.revision)
        return c ? c.name.split(" ")[0] : ""
    }

    // The client's own sessions in the shown days
    readonly property var mySessions: {
        if (!Session.loggedIn)
            return []
        const list = []
        const mine = CalendarStore.clientSessions(Session.user.email, Session.user.name, CalendarStore.revision)
                                  .filter(s => CalendarStore.isActive(s) && s.coachId === coachId)
        shownIndexes.forEach((dayIndex, column) => {
            const key = CalendarStore.dateKey(days[dayIndex])
            mine.filter(s => s.dateKey === key).forEach(s => list.push({ column: column, session: s }))
        })
        return list
    }

    // Free 30-minute slots in the shown week
    readonly property int freeSlotCount: {
        let n = 0
        days.forEach(d => { for (let m = range.from; m < range.to; m += CalendarStore.slotMinutes) if (CalendarStore.isCoachSlotFree(coachId, d, m, CalendarStore.revision)) ++n })
        return n
    }

    // Picked a time: open the request dialog
    signal requestRequested(double dayMs, int start, int end)

    function slotMinute(slot) {
        return range.from + slot * CalendarStore.slotMinutes
    }

    function isFree(dayIndex, minute) {
        return CalendarStore.isCoachSlotFree(coachId, days[dayIndex], minute, CalendarStore.revision)
    }

    function isMine(dayIndex, minute) {
        const key = CalendarStore.dateKey(days[dayIndex])
        return mySessions.some(x => x.session.dateKey === key && minute >= x.session.start && minute < x.session.end)
    }

    // "free" | "mine" | "unavailable" | "outside"
    function cellState(dayIndex, minute) {
        if (isMine(dayIndex, minute))
            return "mine"
        if (isFree(dayIndex, minute))
            return "free"
        return CalendarStore.isCoachWorkingSlot(coachId, days[dayIndex], minute, CalendarStore.revision) ? "unavailable" : "outside"
    }

    function clearSelection() {
        selDay = -1
        selFrom = -1
        selTo = -1
    }

    function goToWeek(delta) {
        weekStart = CalendarStore.addDays(weekStart, 7 * delta)
        clearSelection()
    }

    function weekLabel() {
        const a = new Date(weekStart)
        const b = new Date(CalendarStore.addDays(weekStart, 6))
        if (a.getMonth() === b.getMonth())
            return Qt.formatDate(a, "d") + " – " + Qt.formatDate(b, "d MMMM yyyy")
        return Qt.formatDate(a, "d MMM") + " – " + Qt.formatDate(b, "d MMM yyyy")
    }

    // Select from `anchor` (a free slot) towards `target` on the same day,
    // stopping at the first slot that isn't free and at the maximum length
    function selectBetween(dayIndex, anchor, target) {
        const step = CalendarStore.slotMinutes
        const maxSlots = CalendarStore.maxSessionMinutes / step
        let from = anchor
        let to = anchor + step
        if (target >= anchor) {
            for (let m = anchor + step; m <= target && (m - anchor) / step < maxSlots && isFree(dayIndex, m); m += step)
                to = m + step
        } else {
            for (let m = anchor - step; m >= target && (anchor + step - m) / step <= maxSlots && isFree(dayIndex, m); m -= step)
                from = m
        }
        selDay = dayIndex
        selFrom = from
        selTo = to
    }

    // − / + on the length
    function canLengthen() {
        return hasSelection && selTo - selFrom < CalendarStore.maxSessionMinutes && isFree(selDay, selTo)
    }
    function lengthen() {
        if (canLengthen())
            selTo += CalendarStore.slotMinutes
    }
    function shorten() {
        if (hasSelection && selTo - selFrom > CalendarStore.slotMinutes)
            selTo -= CalendarStore.slotMinutes
    }

    // Open on the first week with free slots (runs again once the coach is known)
    function showFirstFreeWeek() {
        clearSelection()
        weekStart = firstWeek
        for (let w = 0; w < CalendarStore.bookingWeeks; ++w) {
            const monday = CalendarStore.addDays(firstWeek, 7 * w)
            const free = [0, 1, 2, 3, 4, 5, 6].findIndex(i =>
                CalendarStore.bookableStarts(coachId, CalendarStore.addDays(monday, i), CalendarStore.slotMinutes, CalendarStore.revision).length > 0)
            if (free >= 0) {
                weekStart = monday
                if (w > 0 || selectedDay < free)
                    selectedDay = free
                break
            }
        }
    }

    onCoachIdChanged: showFirstFreeWeek()
    Component.onCompleted: showFirstFreeWeek()

    // A selection that stopped being free (e.g. someone else booked it) is dropped
    onFreeSlotCountChanged: {
        if (hasSelection && !CalendarStore.isRangeFree(coachId, days[selDay], selFrom, selTo, CalendarStore.revision))
            clearSelection()
    }

    spacing: 14

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        IconButton {
            glyph: "‹"
            tooltip: qsTr("Previous week")
            enabled: root.weekStart > root.firstWeek
            onClicked: root.goToWeek(-1)
        }
        IconButton {
            glyph: "›"
            tooltip: qsTr("Next week")
            enabled: root.weekStart < root.lastWeek
            onClicked: root.goToWeek(1)
        }
        Label {
            text: root.weekLabel()
            font.pixelSize: root.wide ? Theme.fontTitle : Theme.fontLarge
            font.weight: Font.Bold
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.leftMargin: 8
        }
    }

    // ---- legend ----
    Flow {
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: [
                { label: qsTr("Free"), fill: Theme.surface, edge: Theme.border },
                { label: qsTr("Unavailable"), fill: Theme.surfaceAlt, edge: Theme.surfaceAlt },
                { label: qsTr("Your sessions"), fill: Theme.primary, edge: Theme.primary },
                { label: qsTr("Your requests"), fill: Theme.accentSoft, edge: Theme.accent }
            ]

            RowLayout {
                id: legendItem
                required property var modelData
                spacing: 6

                Rectangle {
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 3
                    color: legendItem.modelData.fill
                    border.width: 1
                    border.color: legendItem.modelData.edge
                }
                Label {
                    text: legendItem.modelData.label
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall + 1
                }
            }
        }
    }

    // ---- day picker (phone) ----
    Flow {
        visible: !root.wide
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: 7
            FilterChip {
                required property int index
                text: Qt.formatDate(new Date(root.days[index]), "ddd d")
                selected: root.selectedDay === index
                onClicked: {
                    root.selectedDay = index
                    root.clearSelection()
                }
            }
        }
    }

    // ---- grid ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + 24
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Item {
            id: grid

            readonly property int headerHeight: 52
            readonly property real columnWidth: (width - root.timeColumnWidth) / root.shownIndexes.length

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            implicitHeight: headerHeight + root.slotCount * root.rowHeight

            // Day headers
            Repeater {
                model: root.shownIndexes.length

                ColumnLayout {
                    id: dayHeader
                    required property int index
                    readonly property double dayMs: root.days[root.shownIndexes[index]] || 0
                    readonly property bool isToday: dayMs === root.todayMs

                    x: root.timeColumnWidth + index * grid.columnWidth
                    width: grid.columnWidth
                    height: grid.headerHeight - 8
                    spacing: 1
                    opacity: dayMs < root.todayMs ? 0.5 : 1

                    Label {
                        text: Qt.formatDate(new Date(dayHeader.dayMs), "ddd").toUpperCase()
                        color: dayHeader.isToday ? Theme.primary : Theme.textMuted
                        font.pixelSize: Theme.fontSmall - 1
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: dayHeader.isToday ? Theme.primary : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: new Date(dayHeader.dayMs).getDate()
                            color: dayHeader.isToday ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.fontLarge
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            Item {
                id: body
                y: grid.headerHeight
                width: grid.width
                height: root.slotCount * root.rowHeight

                // Hour labels
                Repeater {
                    model: root.slotCount
                    Label {
                        required property int index
                        readonly property int minute: root.slotMinute(index)
                        visible: minute % 60 === 0
                        x: 0
                        y: index * root.rowHeight - height / 2
                        width: root.timeColumnWidth - 10
                        horizontalAlignment: Text.AlignRight
                        text: CalendarStore.formatMinutes(minute)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall - 1
                        font.features: { "tnum": 1 }
                    }
                }

                // Slots
                Repeater {
                    model: root.shownIndexes.length * root.slotCount

                    Rectangle {
                        id: cell
                        required property int index
                        readonly property int column: Math.floor(index / root.slotCount)
                        readonly property int dayIndex: root.shownIndexes[column] !== undefined ? root.shownIndexes[column] : 0
                        readonly property int minute: root.slotMinute(index % root.slotCount)
                        readonly property string state_: root.cellState(dayIndex, minute)
                        readonly property bool hovered: root.hover !== null && root.hover.column === column
                                                        && root.hover.minute === minute && state_ === "free"

                        x: root.timeColumnWidth + column * grid.columnWidth + 1
                        y: (index % root.slotCount) * root.rowHeight
                        width: grid.columnWidth - 2
                        height: root.rowHeight - 1
                        radius: 3
                        color: state_ === "free" ? (hovered ? Theme.primarySoft : Theme.surface)
                             : state_ === "unavailable" ? Theme.surfaceAlt
                             : state_ === "outside" ? Theme.background
                             : "transparent"
                        border.width: state_ === "free" ? 1 : 0
                        border.color: Theme.border
                    }
                }

                // Your own sessions
                Repeater {
                    model: root.mySessions

                    Rectangle {
                        id: mine
                        required property var modelData
                        readonly property var session: modelData.session
                        readonly property bool pending: session.status === "pending"

                        x: root.timeColumnWidth + modelData.column * grid.columnWidth + 2
                        y: (session.start - root.range.from) / CalendarStore.slotMinutes * root.rowHeight + 1
                        width: grid.columnWidth - 4
                        height: (session.end - session.start) / CalendarStore.slotMinutes * root.rowHeight - 3
                        radius: 6
                        clip: true
                        z: 1
                        color: pending ? Theme.accentSoft : Theme.primary
                        border.width: pending ? 1.5 : 0
                        border.color: Theme.accent

                        Label {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            anchors.topMargin: 3
                            text: (mine.pending ? qsTr("Requested") : qsTr("Your session")) + " · "
                                  + CalendarStore.formatMinutes(mine.session.start) + "–" + CalendarStore.formatMinutes(mine.session.end)
                            color: mine.pending ? Theme.accent : Theme.textOnPrimary
                            font.pixelSize: Theme.fontSmall - 1
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }

                // Current selection
                Rectangle {
                    readonly property int column: root.shownIndexes.indexOf(root.selDay)
                    visible: root.hasSelection && column >= 0
                    x: root.timeColumnWidth + column * grid.columnWidth + 2
                    y: (root.selFrom - root.range.from) / CalendarStore.slotMinutes * root.rowHeight + 1
                    width: grid.columnWidth - 4
                    height: (root.selTo - root.selFrom) / CalendarStore.slotMinutes * root.rowHeight - 3
                    radius: 6
                    z: 2
                    color: Theme.primary
                    border.width: 2
                    border.color: Theme.primaryHover

                    Label {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        anchors.topMargin: 3
                        text: CalendarStore.formatMinutes(root.selFrom) + "–" + CalendarStore.formatMinutes(root.selTo)
                              + " · " + CalendarStore.durationText(root.selTo - root.selFrom)
                        color: Theme.textOnPrimary
                        font.pixelSize: Theme.fontSmall - 1
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }

                // Click / drag to choose a time
                MouseArea {
                    id: picker

                    property int anchorMinute: -1
                    property int anchorDay: -1

                    function cellAt(px, py) {
                        if (px < root.timeColumnWidth)
                            return null
                        const column = Math.floor((px - root.timeColumnWidth) / grid.columnWidth)
                        const slot = Math.floor(py / root.rowHeight)
                        if (column < 0 || column >= root.shownIndexes.length || slot < 0 || slot >= root.slotCount)
                            return null
                        return { column: column, day: root.shownIndexes[column], minute: root.slotMinute(slot) }
                    }

                    anchors.fill: parent
                    z: 3
                    hoverEnabled: true
                    preventStealing: root.wide
                    cursorShape: root.hover !== null && root.isFree(root.hover.day, root.hover.minute)
                                 ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onPressed: mouse => {
                        const c = cellAt(mouse.x, mouse.y)
                        if (!c || !root.isFree(c.day, c.minute)) {
                            anchorMinute = -1
                            mouse.accepted = false
                            return
                        }
                        anchorDay = c.day
                        anchorMinute = c.minute
                        root.selectBetween(c.day, c.minute, c.minute)
                    }
                    onPositionChanged: mouse => {
                        root.hover = cellAt(mouse.x, mouse.y)
                        if (pressed && anchorMinute >= 0) {
                            // Stay on the day where the drag started
                            const slot = Math.max(0, Math.min(root.slotCount - 1, Math.floor(mouse.y / root.rowHeight)))
                            root.selectBetween(anchorDay, anchorMinute, root.slotMinute(slot))
                        }
                    }
                    onReleased: anchorMinute = -1
                    onCanceled: anchorMinute = -1
                    onExited: root.hover = null
                }
            }
        }
    }

    // ---- selection bar ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: selectionRow.implicitHeight + 24
        radius: Theme.radiusLarge
        color: root.hasSelection ? Theme.primarySoft : Theme.surfaceAlt

        RowLayout {
            id: selectionRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 8

            Label {
                visible: !root.hasSelection
                text: root.freeSlotCount > 0
                      ? qsTr("Click a free slot, or drag over several, to choose when and how long. %1 confirms every request.").arg(root.coachFirstName)
                      : qsTr("No free time this week. Try the next one.")
                color: Theme.textMuted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                visible: root.hasSelection
                spacing: 0
                Layout.fillWidth: true

                Label {
                    text: root.hasSelection
                          ? Qt.formatDate(new Date(root.days[root.selDay]), "dddd d MMMM") + " · "
                            + CalendarStore.formatMinutes(root.selFrom) + "–" + CalendarStore.formatMinutes(root.selTo)
                          : ""
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    text: root.hasSelection ? qsTr("Length: %1").arg(CalendarStore.durationText(root.selTo - root.selFrom)) : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }

            IconButton {
                visible: root.hasSelection
                glyph: "−"
                tooltip: qsTr("30 minutes shorter")
                enabled: root.hasSelection && root.selTo - root.selFrom > CalendarStore.slotMinutes
                onClicked: root.shorten()
            }
            IconButton {
                visible: root.hasSelection
                glyph: "+"
                tooltip: qsTr("30 minutes longer")
                enabled: root.canLengthen()
                onClicked: root.lengthen()
            }
            AuraButton {
                visible: root.hasSelection && root.wide
                variant: "ghost"
                text: qsTr("Clear")
                onClicked: root.clearSelection()
            }
            AuraButton {
                visible: root.hasSelection
                text: root.wide ? qsTr("Request session") : qsTr("Request")
                onClicked: root.requestRequested(root.days[root.selDay], root.selFrom, root.selTo)
            }
        }
    }
}
