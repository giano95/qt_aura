// Messages between a coach and a client, as QML sees them (value types):
//   chatMessage:  { id, coachingId, senderId, body, createdAt (ms), mine,
//                   status: "sent" | "sending" | "failed",
//                   receipt: ticks on the user's own messages (see below) }
//   conversation: { id (the coaching's), open, otherId, otherName,
//                   lastBody, lastAt, lastMine, otherLastBody, otherLastAt,
//                   unread, otherReadAt, otherDeliveredAt, endedAt,
//                   lastReceipt }
// Receipts (WhatsApp ticks) on the user's own messages: "sending" (clock),
// "sent" (one tick: the server has it), "delivered" (two ticks: the other
// person's app has it), "read" (blue ticks), "failed"; "" on the other
// person's messages.
// Times are milliseconds since the epoch; 0 = none.
#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

struct Message
{
    Q_GADGET
    QML_VALUE_TYPE(chatMessage)

    Q_PROPERTY(QString id MEMBER id FINAL)
    Q_PROPERTY(QString coachingId MEMBER coachingId FINAL)
    Q_PROPERTY(QString senderId MEMBER senderId FINAL)
    Q_PROPERTY(QString body MEMBER body FINAL)
    Q_PROPERTY(double createdAt MEMBER createdAt FINAL)
    // Sent by the signed-in user
    Q_PROPERTY(bool mine MEMBER mine FINAL)
    // "sent" | "sending" (on its way) | "failed" (can be sent again)
    Q_PROPERTY(QString status MEMBER status FINAL)
    // Ticks: "" | "sending" | "sent" | "delivered" | "read" | "failed"
    Q_PROPERTY(QString receipt MEMBER receipt FINAL)

public:
    QString id;
    QString coachingId;
    QString senderId;
    QString body;
    double createdAt = 0;
    bool mine = false;
    QString status = QStringLiteral("sent");
    QString receipt;        // filled by MessageStore::messages()
    // The server's timestamp as sent (microseconds), for queries
    QString createdAtIso;

    bool pending() const { return status != QLatin1String("sent"); }
    static Message fromJson(const QJsonObject &row, const QString &myId);
    friend bool operator==(const Message &, const Message &) = default;
};

// One coaching seen as a conversation (a row of the `conversations()` function)
struct Conversation
{
    Q_GADGET
    QML_VALUE_TYPE(conversation)

    // The coaching's id
    Q_PROPERTY(QString id MEMBER id FINAL)
    // Active or paused coaching: both can write. Ended: read-only.
    Q_PROPERTY(bool open MEMBER open FINAL)
    Q_PROPERTY(QString otherId MEMBER otherId FINAL)
    Q_PROPERTY(QString otherName MEMBER otherName FINAL)
    // Last message from either side ("" / 0 without messages)
    Q_PROPERTY(QString lastBody MEMBER lastBody FINAL)
    Q_PROPERTY(double lastAt MEMBER lastAt FINAL)
    Q_PROPERTY(bool lastMine MEMBER lastMine FINAL)
    // Last message from the other person
    Q_PROPERTY(QString otherLastBody MEMBER otherLastBody FINAL)
    Q_PROPERTY(double otherLastAt MEMBER otherLastAt FINAL)
    // Messages from the other person the user hasn't read
    Q_PROPERTY(int unread MEMBER unread FINAL)
    // How far the other person has read / their app has received: the
    // user's messages up to here have blue / two ticks
    Q_PROPERTY(double otherReadAt MEMBER otherReadAt FINAL)
    Q_PROPERTY(double otherDeliveredAt MEMBER otherDeliveredAt FINAL)
    // Ticks of the last message when it's the user's ("" otherwise)
    Q_PROPERTY(QString lastReceipt MEMBER lastReceipt FINAL)
    Q_PROPERTY(double endedAt MEMBER endedAt FINAL)

public:
    QString id;
    bool open = false;
    QString otherId;
    QString otherName;
    QString lastId;
    QString lastBody;
    double lastAt = 0;
    bool lastMine = false;
    QString otherLastBody;
    double otherLastAt = 0;
    int unread = 0;
    double otherReadAt = 0;
    double otherDeliveredAt = 0;
    double myDeliveredAt = 0;
    double endedAt = 0;
    QString lastReceipt;        // filled by MessageStore::conversations()
    QString lastAtIso;          // for mark_read
    QString otherLastAtIso;     // for mark_delivered

    static Conversation fromJson(const QJsonObject &row, const QString &myId);
    friend bool operator==(const Conversation &, const Conversation &) = default;
};
