import QtQuick

// The ticks after the time of the user's own message, like WhatsApp:
// "sending" a clock, "sent" one tick, "delivered" two ticks, "read" two ticks
// in `readColor`, "failed" an exclamation mark in `failedColor`. Draws nothing
// for "" (the other person's messages). Drawn, not text: tick characters look
// different (or are missing) in the macOS and Windows fonts.
Canvas {
    id: ticks

    property string receipt: ""
    property color color: Theme.textMuted
    property color readColor: Theme.receiptRead
    property color failedColor: Theme.danger

    readonly property bool twoTicks: receipt === "delivered" || receipt === "read"

    visible: receipt.length > 0
    implicitWidth: twoTicks ? 16 : 11
    implicitHeight: 11

    Accessible.role: Accessible.StaticText
    Accessible.name: receipt === "sending" ? qsTr("Sending")
                   : receipt === "sent" ? qsTr("Sent")
                   : receipt === "delivered" ? qsTr("Delivered")
                   : receipt === "read" ? qsTr("Read")
                   : receipt === "failed" ? qsTr("Not sent")
                   : ""

    onReceiptChanged: requestPaint()
    onColorChanged: requestPaint()
    onReadColorChanged: requestPaint()
    onFailedColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.lineWidth = 1.5
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = receipt === "read" ? readColor
                        : receipt === "failed" ? failedColor
                        : color
        ctx.beginPath()
        if (receipt === "sending") {
            // A clock at ten past
            ctx.arc(5.5, 5.5, 4.5, 0, 2 * Math.PI)
            ctx.moveTo(5.5, 3)
            ctx.lineTo(5.5, 5.5)
            ctx.lineTo(7.3, 6.5)
        } else if (receipt === "failed") {
            ctx.arc(5.5, 5.5, 4.5, 0, 2 * Math.PI)
            ctx.moveTo(5.5, 3.2)
            ctx.lineTo(5.5, 6)
            ctx.moveTo(5.5, 7.9)
            ctx.lineTo(5.5, 8)
        } else if (receipt.length > 0) {
            ctx.moveTo(1, 6)
            ctx.lineTo(3.7, 8.7)
            ctx.lineTo(10, 2.3)
            if (twoTicks) {
                // The second tick's short stroke hides behind the first one
                ctx.moveTo(7.6, 7.6)
                ctx.lineTo(8.7, 8.7)
                ctx.lineTo(15, 2.3)
            }
        }
        ctx.stroke()
    }
}
