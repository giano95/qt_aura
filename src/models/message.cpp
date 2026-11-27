// See message.hpp.
#include "message.hpp"

#include "coaching.hpp"

namespace {

QString str(const QJsonObject &row, const char *key)
{
    return row.value(QLatin1String(key)).toString();
}

double time(const QJsonObject &row, const char *key)
{
    return AuraDates::fromIsoDateTime(str(row, key));
}

} // namespace

Message Message::fromJson(const QJsonObject &row, const QString &myId)
{
    Message m;
    m.id = str(row, "id");
    m.coachingId = str(row, "coaching_id");
    m.senderId = str(row, "sender_id");
    m.body = str(row, "body");
    m.createdAtIso = str(row, "created_at");
    m.createdAt = time(row, "created_at");
    m.mine = m.senderId == myId;
    return m;
}

Conversation Conversation::fromJson(const QJsonObject &row, const QString &myId)
{
    Conversation c;
    c.id = str(row, "coaching_id");
    const QString status = str(row, "status");
    c.open = status == QLatin1String("active") || status == QLatin1String("paused");
    c.otherId = str(row, "other_id");
    c.otherName = str(row, "other_name");
    c.lastId = str(row, "last_id");
    c.lastBody = str(row, "last_body");
    c.lastAtIso = str(row, "last_at");
    c.lastAt = time(row, "last_at");
    c.lastMine = !c.lastId.isEmpty() && str(row, "last_sender") == myId;
    c.otherLastBody = str(row, "other_last_body");
    c.otherLastAtIso = str(row, "other_last_at");
    c.otherLastAt = time(row, "other_last_at");
    c.unread = row.value(QStringLiteral("unread")).toInt();
    c.otherReadAt = time(row, "other_read_at");
    c.otherDeliveredAt = time(row, "other_delivered_at");
    c.myDeliveredAt = time(row, "my_delivered_at");
    c.endedAt = time(row, "ended_at");
    return c;
}
