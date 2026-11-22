pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Week view of the coach's availability in 30-minute slots.
//  - inside working hours: free (white) or blocked (red)
//  - outside working hours: grey
//  - booked sessions drawn on top
// Click a free slot to block it, drag to block several; starting on a blocked
// slot frees instead. Past slots and booked sessions can't be changed.
// Narrow screens show one day at a time.
ColumnLayout {
    id: root

    property bool wide: true
    property double weekStart: CalendarStore.mondayOf(Date.now())
    property int selectedDay: (new Date().getDay() + 6) % 7      // shown day on narrow screens, 0 = Monday
    property var hover: null                                      // { day, slot } under the pointer

    // A session was clicked (request, confirmed or past): the page opens its details
    signal sessionClicked(string sessionId)

    readonly property double todayMs: CalendarStore.startOfDay(CalendarStore.now)
    readonly property var days: [0, 1, 2, 3, 4, 5, 6].map(i => CalendarStore.addDays(weekStart, i))
    readonly property var shownDays: wide ? days : [days[selectedDay]]
    readonly property var range: CalendarStore.visibleRange(weekStart, CalendarStore.revision)
    readonly property int slotCount: (range.to - range.from) / CalendarStore.slotMinutes
    readonly property var stats: CalendarStore.weekStats(weekStart, CalendarStore.revision)
    readonly property int timeColumnWidth: 52
    readonly property int rowHeight: wide ? 24 : 34
    readonly property bool isCurrentWeek: weekStart === CalendarStore.mondayOf(CalendarStore.now)
    // Sessions of the shown days. Sessions that overlap (a double booking) get
    // a `lane` each and are drawn side by side; `lanes` is how many share the group.
    readonly property var shownSessions: {
        const list = []
        shownDays.forEach((day, dayIndex) => {
            let group = []
            let groupEnd = -1
            const flush = () => {
                const lanes = Math.max(...group.map(g => g.lane)) + 1
                group.forEach(g => { g.lanes = lanes; list.push(g) })
                group = []
            }
            CalendarStore.sessionsOn(day, CalendarStore.revision).forEach(s => {
                if (group.length > 0 && s.start >= groupEnd)
                    flush()
                const busy = group.filter(g => g.session.end > s.start).map(g => g.lane)
                let lane = 0
                while (busy.includes(lane))
                    ++lane
                group.push({ dayIndex: dayIndex, dayMs: day, session: s, lane: lane, lanes: 1 })
                groupEnd = Math.max(groupEnd, s.end)
            })
            if (group.length > 0)
                flush()
        })
        return list
    }

    function slotMinute(slot) {
        return range.from + slot * CalendarStore.slotMinutes
    }

    function goToWeek(delta) {
        weekStart = CalendarStore.addDays(weekStart, 7 * delta)
        hover = null
    }

    function goToToday() {
        weekStart = CalendarStore.mondayOf(Date.now())
        selectedDay = (new Date().getDay() + 6) % 7
    }

    function weekLabel() {
        const a = new Date(weekStart)
        const b = new Date(CalendarStore.addDays(weekStart, 6))
        if (a.getMonth() === b.getMonth())
            return Qt.formatDate(a, "d") + " – " + Qt.formatDate(b, "d MMMM yyyy")
        return Qt.formatDate(a, "d MMM") + " – " + Qt.formatDate(b, "d MMM yyyy")
    }

    // Slots of a day that could be blocked (value true) or freed (false) now
    function changeableSlots(dayMs, toBlocked) {
        const list = []
        for (let m = 0; m < 24 * 60; m += CalendarStore.slotMinutes) {
            if (!CalendarStore.isToggleable(dayMs, m, CalendarStore.revision))
                continue
            if (CalendarStore.isBlocked(dayMs, m, CalendarStore.revision) !== toBlocked)
                list.push(m)
        }
        return list
    }

    function setDayBlocked(dayMs, value) {
        CalendarStore.setBlocked(dayMs, changeableSlots(dayMs, value), value)
    }

    function hoverText() {
        if (!hover)
            return qsTr("Click a free slot to block it, or drag across several. Click a blocked slot to free it again.")
        const day = shownDays[hover.day]
        const minute = slotMinute(hover.slot)
        const when = Qt.formatDate(new Date(day), "ddd d MMM") + " · "
                   + CalendarStore.formatMinutes(minute) + "–" + CalendarStore.formatMinutes(minute + CalendarStore.slotMinutes)
        const here = CalendarStore.sessionsOn(day, CalendarStore.revision).filter(s => minute >= s.start && minute < s.end)
        if (here.length > 1)
            return when + " · " + qsTr("Double booked: %1").arg(here.map(s => s.client).join(", "))
        if (here.length === 1 && here[0].status === "pending")
            return when + " · " + qsTr("%1 asked for this session: click to see the request").arg(here[0].client)
        if (here.length === 1)
            return when + " · " + qsTr("Session with %1: click for details").arg(here[0].client)
        if (CalendarStore.isPast(day, minute, CalendarStore.revision))
            return when + " · " + qsTr("Already passed")
        switch (CalendarStore.slotState(day, minute, CalendarStore.revision)) {
        case "available": return when + " · " + qsTr("Free: click to block")
        case "blocked": return when + " · " + qsTr("Blocked: click to free")
        default: return when + " · " + qsTr("Outside your working hours")
        }
    }

    spacing: 14

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        IconButton {
            glyph: "‹"
            tooltip: qsTr("Previous week")
            onClicked: root.goToWeek(-1)
        }
        IconButton {
            glyph: "›"
            tooltip: qsTr("Next week")
            onClicked: root.goToWeek(1)
        }
        AuraButton {
            variant: "secondary"
            text: qsTr("Today")
            enabled: !root.isCurrentWeek
            implicitHeight: 34
            leftPadding: 12
            rightPadding: 12
            onClicked: root.goToToday()
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

    // ---- legend with this week's totals ----
    Flow {
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: [
                { label: qsTr("Free · %1").arg(CalendarStore.hoursText(root.stats.availableHours)), fill: Theme.surface, edge: Theme.border },
                { label: qsTr("Blocked · %1").arg(CalendarStore.hoursText(root.stats.blockedHours)), fill: Theme.dangerSoft, edge: Theme.dangerSoft },
                { label: root.stats.sessions === 1 ? qsTr("Booked · 1 session") : qsTr("Booked · %1 sessions").arg(root.stats.sessions), fill: Theme.primary, edge: Theme.primary },
                { label: qsTr("Requested by a client"), fill: Theme.accentSoft, edge: Theme.accent },
                { label: qsTr("Outside working hours"), fill: Theme.surfaceAlt, edge: Theme.surfaceAlt }
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
                marked: CalendarStore.blocked[CalendarStore.dateKey(root.days[index])] !== undefined
                onClicked: root.selectedDay = index
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
            readonly property real columnWidth: (width - root.timeColumnWidth) / root.shownDays.length

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            implicitHeight: headerHeight + root.slotCount * root.rowHeight

            // Day headers (click for whole-day actions)
            Repeater {
                model: root.shownDays.length

                AbstractButton {
                    id: dayHeader
                    required property int index
                    readonly property double dayMs: root.shownDays[index] || 0
                    readonly property bool isToday: dayMs === root.todayMs
                    readonly property bool isPastDay: dayMs < root.todayMs

                    x: root.timeColumnWidth + index * grid.columnWidth
                    width: grid.columnWidth
                    height: grid.headerHeight - 8
                    enabled: !isPastDay
                    hoverEnabled: true
                    onClicked: {
                        dayMenu.dayMs = dayHeader.dayMs
                        dayMenu.popup(dayHeader, (dayHeader.width - dayMenu.width) / 2, dayHeader.height)
                    }

                    contentItem: ColumnLayout {
                        spacing: 1
                        opacity: dayHeader.isPastDay ? 0.5 : 1

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

                    background: Rectangle {
                        radius: 8
                        color: dayHeader.hovered && dayHeader.enabled ? Theme.surfaceAlt : "transparent"
                    }

                    ToolTip.visible: hovered && enabled
                    ToolTip.text: qsTr("Block or free the whole day")
                    ToolTip.delay: 600
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
                    model: root.shownDays.length * root.slotCount

                    Rectangle {
                        id: cell
                        required property int index
                        readonly property int dayIndex: Math.floor(index / root.slotCount)
                        readonly property int slot: index % root.slotCount
                        readonly property double dayMs: root.shownDays[dayIndex] || 0
                        readonly property int minute: root.slotMinute(slot)
                        readonly property string slotState: CalendarStore.slotState(dayMs, minute, CalendarStore.revision)
                        readonly property bool past: CalendarStore.isPast(dayMs, minute, CalendarStore.revision)
                        readonly property bool hovered: root.hover !== null && root.hover.day === dayIndex && root.hover.slot === slot
                        readonly property bool changeable: !past && (slotState === "available" || slotState === "blocked")
                        readonly property bool firstBlocked: slotState === "blocked"
                                                            && (slot === 0 || CalendarStore.slotState(dayMs, minute - CalendarStore.slotMinutes, CalendarStore.revision) !== "blocked")

                        x: root.timeColumnWidth + dayIndex * grid.columnWidth + 1
                        y: slot * root.rowHeight
                        width: grid.columnWidth - 2
                        height: root.rowHeight - 1
                        radius: 3
                        opacity: past ? 0.45 : 1
                        color: slotState === "blocked" ? (hovered && changeable ? Qt.darker(Theme.dangerSoft, 1.06) : Theme.dangerSoft)
                             : slotState === "available" ? (hovered && changeable ? Theme.primarySoft : Theme.surface)
                             : Theme.surfaceAlt
                        border.width: slotState === "available" ? 1 : 0
                        border.color: minute % 60 === 0 ? Qt.darker(Theme.border, 1.05) : Theme.border

                        Label {
                            visible: cell.firstBlocked || (cell.hovered && cell.changeable)
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 4
                            text: cell.hovered && cell.changeable
                                  ? (cell.slotState === "blocked" ? qsTr("Free") : qsTr("Block"))
                                  : qsTr("Blocked")
                            color: cell.slotState === "blocked" ? Theme.danger : Theme.primary
                            font.pixelSize: Theme.fontSmall - 1
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }

                // "Now" line on today's column
                Rectangle {
                    readonly property int dayIndex: root.shownDays.indexOf(root.todayMs)
                    readonly property real minuteNow: (CalendarStore.now - root.todayMs) / 60000
                    visible: dayIndex >= 0 && minuteNow >= root.range.from && minuteNow <= root.range.to
                    x: root.timeColumnWidth + dayIndex * grid.columnWidth - 4
                    y: (minuteNow - root.range.from) / CalendarStore.slotMinutes * root.rowHeight - 1
                    width: grid.columnWidth + 4
                    height: 2
                    color: Theme.danger
                    z: 2

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.danger
                    }
                }

                // Booked sessions (drawn over the slots; clicks go to the MouseArea below,
        // which opens pending ones)
                Repeater {
                    model: root.shownSessions

                    Rectangle {
                        id: sessionBlock
                        required property var modelData
                        readonly property var session: modelData.session
                        readonly property bool past: CalendarStore.isPast(modelData.dayMs, session.end - CalendarStore.slotMinutes, CalendarStore.revision)
                        readonly property bool overlaps: modelData.lanes > 1
                        readonly property bool pending: session.status === "pending"
                        readonly property real laneWidth: (grid.columnWidth - 4) / modelData.lanes

                        x: root.timeColumnWidth + modelData.dayIndex * grid.columnWidth + 2 + modelData.lane * laneWidth
                        y: (session.start - root.range.from) / CalendarStore.slotMinutes * root.rowHeight + 1
                        width: laneWidth - (overlaps ? 2 : 0)
                        height: (session.end - session.start) / CalendarStore.slotMinutes * root.rowHeight - 3
                        radius: 6
                        // Confirmed: solid primary. Requested by a client: amber outline.
                        color: pending ? Theme.accentSoft : Theme.primary
                        // Faded when past; mixed with the surface rather than see-through,
                        // so nothing underneath shows through the text
                        opacity: 1
                        clip: true
                        z: 1
                        border.width: overlaps ? 2 : (pending ? 1.5 : 0)
                        border.color: overlaps ? Theme.danger : Theme.accent

                        Rectangle {
                            visible: sessionBlock.past
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.surface
                            opacity: 0.45
                            z: 2        // over the text and badge too
                        }

                        // Badge: what can be done with it. Requests need an answer;
                        // confirmed sessions have options (details, cancel).
                        Rectangle {
                            visible: !sessionBlock.past
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 3
                            z: 1
                            height: 16
                            width: sessionBlock.pending ? respondText.implicitWidth + 12 : 16
                            radius: 8
                            color: sessionBlock.pending ? Theme.accent : Qt.rgba(1, 1, 1, Theme.dark ? 0.25 : 0.3)

                            Text {
                                id: respondText
                                anchors.centerIn: parent
                                text: sessionBlock.pending ? qsTr("Respond") : "⋯"
                                color: sessionBlock.pending ? (Theme.dark ? "#2A1A05" : "#FFFFFF") : Theme.textOnPrimary
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            anchors.topMargin: 4
                            anchors.rightMargin: sessionBlock.pending ? 62 : 22    // room for the badge
                            spacing: 0

                            Label {
                                text: sessionBlock.pending ? qsTr("Request · %1").arg(sessionBlock.session.client) : sessionBlock.session.client
                                color: sessionBlock.pending ? Theme.accent : Theme.textOnPrimary
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: CalendarStore.formatMinutes(sessionBlock.session.start) + " · " + sessionBlock.session.type
                                color: sessionBlock.pending ? Theme.accent : Theme.textOnPrimary
                                opacity: 0.85
                                font.pixelSize: Theme.fontSmall - 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // Click / drag to block or free slots
                MouseArea {
                    id: painter

                    property int mode: 0        // 1 = blocking, -1 = freeing, 0 = idle
                    property var lastCell: null

                    function cellAt(px, py) {
                        if (px < root.timeColumnWidth)
                            return null
                        const day = Math.floor((px - root.timeColumnWidth) / grid.columnWidth)
                        const slot = Math.floor(py / root.rowHeight)
                        if (day < 0 || day >= root.shownDays.length || slot < 0 || slot >= root.slotCount)
                            return null
                        return { day: day, slot: slot }
                    }

                    // Applies to every cell between the previous pointer position and
                    // `c`, so a fast drag doesn't skip slots
                    function applyTo(c) {
                        if (!c)
                            return
                        const from = lastCell || c
                        const d0 = Math.min(from.day, c.day), d1 = Math.max(from.day, c.day)
                        const s0 = Math.min(from.slot, c.slot), s1 = Math.max(from.slot, c.slot)
                        for (let d = d0; d <= d1; ++d)
                            for (let s = s0; s <= s1; ++s)
                                apply({ day: d, slot: s })
                        lastCell = c
                    }

                    function apply(c) {
                        if (!c)
                            return
                        const day = root.shownDays[c.day]
                        const minute = root.slotMinute(c.slot)
                        if (!CalendarStore.isToggleable(day, minute, CalendarStore.revision))
                            return
                        const isBlocked = CalendarStore.isBlocked(day, minute, CalendarStore.revision)
                        if (mode === 1 && !isBlocked)
                            CalendarStore.setBlocked(day, [minute], true)
                        else if (mode === -1 && isBlocked)
                            CalendarStore.setBlocked(day, [minute], false)
                    }

                    anchors.fill: parent
                    z: 3
                    hoverEnabled: true
                    // Desktop: dragging paints slots. Touch: dragging scrolls the page.
                    preventStealing: root.wide
                    // The session under the pointer, or null
                    function sessionAtCell(c) {
                        return c ? CalendarStore.sessionAt(root.shownDays[c.day], root.slotMinute(c.slot), CalendarStore.revision) : null
                    }

                    cursorShape: root.hover !== null
                                 && (CalendarStore.isToggleable(root.shownDays[root.hover.day], root.slotMinute(root.hover.slot), CalendarStore.revision)
                                     || sessionAtCell(root.hover) !== null)
                                 ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onPressed: mouse => {
                        const c = cellAt(mouse.x, mouse.y)
                        mode = 0
                        const session = sessionAtCell(c)
                        if (session) {
                            root.sessionClicked(session.id)
                            return
                        }
                        if (!c || !CalendarStore.isToggleable(root.shownDays[c.day], root.slotMinute(c.slot), CalendarStore.revision)) {
                            mouse.accepted = false
                            return
                        }
                        mode = CalendarStore.isBlocked(root.shownDays[c.day], root.slotMinute(c.slot), CalendarStore.revision) ? -1 : 1
                        lastCell = null
                        applyTo(c)
                    }
                    onPositionChanged: mouse => {
                        root.hover = cellAt(mouse.x, mouse.y)
                        if (pressed && mode !== 0)
                            applyTo(root.hover)
                    }
                    onReleased: {
                        mode = 0
                        lastCell = null
                    }
                    onCanceled: {
                        mode = 0
                        lastCell = null
                    }
                    onExited: root.hover = null
                }
            }
        }
    }

    Label {
        text: root.hoverText()
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall + 1
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    AuraMenu {
        id: dayMenu

        property double dayMs: 0

        Action {
            text: qsTr("Block whole day")
            enabled: dayMenu.dayMs > 0 && root.changeableSlots(dayMenu.dayMs, true).length > 0
            objectName: "destructive"
            onTriggered: root.setDayBlocked(dayMenu.dayMs, true)
        }
        Action {
            text: qsTr("Free whole day")
            enabled: dayMenu.dayMs > 0 && root.changeableSlots(dayMenu.dayMs, false).length > 0
            onTriggered: root.setDayBlocked(dayMenu.dayMs, false)
        }
    }
}
