// See messagestore.hpp.
#include "messagestore.hpp"

#include "coaching.hpp"
#include "supabaseclient.hpp"

#include <QDateTime>
#include <QJsonObject>
#include <QLocale>
#include <QUrlQuery>

#include <algorithm>

namespace {

constexpr int kPageSize = 50;
constexpr int kMaxLength = 4000;
const QString kColumns = QStringLiteral("id,coaching_id,sender_id,body,created_at");

QDate localDate(double ms)
{
    return QDateTime::fromMSecsSinceEpoch(qint64(ms)).date();
}

// A server timestamp ("…+00:00") as a query value: a "+" in a URL query
// arrives as a space, so UTC is written as "Z" (anything else escaped)
QString queryTime(const QString &iso)
{
    QString t = iso;
    if (t.endsWith(QLatin1String("+00:00"))) {
        t.chop(6);
        t += QLatin1Char('Z');
    }
    t.replace(QLatin1Char('+'), QStringLiteral("%2B"));
    return t;
}

} // namespace

MessageStore::MessageStore(QObject *parent)
    : StoreBase(parent)
{
    start({QStringLiteral("messages"), QStringLiteral("message_reads"), QStringLiteral("coachings")});
}

// ---- loading --------------------------------------------------------------------

void MessageStore::load()
{
    // Conversations, plus what's new in every conversation already opened
    QStringList opened;
    for (auto it = m_threads.cbegin(); it != m_threads.cend(); ++it)
        if (it->fetched)
            opened.append(it.key());
    const int generation = beginLoad(1 + int(opened.size()));

    m_client->rpc(this, QStringLiteral("conversations"), {},
                  [this, generation](const SupabaseClient::Reply &reply) {
                      if (!isCurrent(generation))
                          return;
                      endLoadStep();
                      if (!reply.ok()) {
                          emit errorOccurred(errorText(reply.errorCode));
                          return;
                      }
                      QHash<QString, QString> lastBefore;
                      for (const Conversation &c : std::as_const(m_conversations))
                          lastBefore.insert(c.id, c.lastId);
                      const QString me = userId();
                      QList<Conversation> list;
                      const QJsonArray rows = reply.data.array();
                      for (const QJsonValue &row : rows)
                          list.append(Conversation::fromJson(row.toObject(), me));

                      QList<Conversation> arrived;
                      if (m_loadedOnce) {
                          for (const Conversation &c : std::as_const(list))
                              if (!c.lastId.isEmpty() && !c.lastMine && c.unread > 0
                                  && lastBefore.value(c.id) != c.lastId)
                                  arrived.append(c);
                      }
                      m_loadedOnce = true;
                      m_conversations = list;
                      sortConversations();
                      markDelivered();
                      changed();
                      for (const Conversation &c : std::as_const(arrived))
                          emit messageReceived(c.id, c.otherName, c.lastBody);
                  });

    for (const QString &id : std::as_const(opened)) {
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("select"), kColumns);
        query.addQueryItem(QStringLiteral("coaching_id"), QStringLiteral("eq.") + id);
        const QString newest = newestIso(m_threads.value(id));
        if (!newest.isEmpty())
            query.addQueryItem(QStringLiteral("created_at"), QStringLiteral("gte.") + queryTime(newest));
        query.addQueryItem(QStringLiteral("order"), QStringLiteral("created_at.asc"));
        query.addQueryItem(QStringLiteral("limit"), QStringLiteral("1000"));
        m_client->select(this, QStringLiteral("messages"), query,
                         [this, generation, id](const SupabaseClient::Reply &reply) {
                             if (!isCurrent(generation))
                                 return;
                             endLoadStep();
                             if (!reply.ok()) {
                                 emit errorOccurred(errorText(reply.errorCode));
                                 return;
                             }
                             const auto it = m_threads.find(id);
                             if (it == m_threads.end())
                                 return;
                             merge(*it, reply.data.array());
                             changed();
                         });
    }
}

void MessageStore::fetchFirstPage(const QString &id)
{
    if (id.isEmpty())
        return;
    Thread &thread = m_threads[id];
    if (thread.fetched || thread.fetching)
        return;
    thread.fetching = true;
    changed();

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("select"), kColumns);
    query.addQueryItem(QStringLiteral("coaching_id"), QStringLiteral("eq.") + id);
    query.addQueryItem(QStringLiteral("order"), QStringLiteral("created_at.desc"));
    query.addQueryItem(QStringLiteral("limit"), QString::number(kPageSize));
    const int epoch = m_epoch;
    m_client->select(this, QStringLiteral("messages"), query,
                     [this, epoch, id](const SupabaseClient::Reply &reply) {
                         if (epoch != m_epoch)
                             return;
                         const auto it = m_threads.find(id);
                         if (it == m_threads.end())
                             return;
                         it->fetching = false;
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             changed();
                             return;
                         }
                         const QJsonArray rows = reply.data.array();
                         it->fetched = true;
                         it->hasOlder = rows.size() == kPageSize;
                         merge(*it, rows);
                         changed();
                     });
}

void MessageStore::loadOlder(const QString &id)
{
    const auto it = m_threads.find(id);
    if (it == m_threads.end() || !it->fetched || !it->hasOlder || it->loadingOlder)
        return;
    const auto oldest = std::find_if(it->messages.cbegin(), it->messages.cend(),
                                     [](const Message &m) { return !m.pending(); });
    if (oldest == it->messages.cend())
        return;
    it->loadingOlder = true;

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("select"), kColumns);
    query.addQueryItem(QStringLiteral("coaching_id"), QStringLiteral("eq.") + id);
    query.addQueryItem(QStringLiteral("created_at"), QStringLiteral("lt.") + queryTime(oldest->createdAtIso));
    query.addQueryItem(QStringLiteral("order"), QStringLiteral("created_at.desc"));
    query.addQueryItem(QStringLiteral("limit"), QString::number(kPageSize));
    const int epoch = m_epoch;
    m_client->select(this, QStringLiteral("messages"), query,
                     [this, epoch, id](const SupabaseClient::Reply &reply) {
                         if (epoch != m_epoch)
                             return;
                         const auto it = m_threads.find(id);
                         if (it == m_threads.end())
                             return;
                         it->loadingOlder = false;
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         const QJsonArray rows = reply.data.array();
                         it->hasOlder = rows.size() == kPageSize;
                         merge(*it, rows);
                         changed();
                     });
}

void MessageStore::merge(Thread &thread, const QJsonArray &rows)
{
    const QString me = userId();
    for (const QJsonValue &value : rows) {
        const Message m = Message::fromJson(value.toObject(), me);
        const auto existing = std::find_if(thread.messages.begin(), thread.messages.end(),
                                           [&](const Message &x) { return x.id == m.id; });
        if (existing == thread.messages.end())
            thread.messages.append(m);
        else if (existing->pending())
            *existing = m;      // our unsent copy reached the server
    }
    // Oldest first; messages still on their way (or failed) stay at the end
    std::stable_sort(thread.messages.begin(), thread.messages.end(), [](const Message &a, const Message &b) {
        if (a.pending() != b.pending())
            return !a.pending();
        return a.pending() ? false : a.createdAt < b.createdAt;
    });
}

bool MessageStore::clearData()
{
    ++m_epoch;
    m_loadedOnce = false;
    const bool had = !m_conversations.isEmpty() || !m_threads.isEmpty();
    m_conversations.clear();
    m_threads.clear();
    if (!m_selectedId.isEmpty()) {
        m_selectedId.clear();
        emit selectedIdChanged();
    }
    return had;
}

QString MessageStore::errorText(const QString &code) const
{
    if (code == QLatin1String("conversation_closed"))
        return tr("This coaching has ended, so the conversation is read-only.");
    if (code == QLatin1String("invalid_length"))
        return tr("A message can't be empty or longer than %1 characters.").arg(kMaxLength);
    return StoreBase::errorText(code);
}

// ---- reading --------------------------------------------------------------------

int MessageStore::unreadTotal() const
{
    int total = 0;
    for (const Conversation &c : m_conversations)
        total += c.unread;
    return total;
}

void MessageStore::setSelectedId(const QString &id)
{
    if (id == m_selectedId)
        return;
    m_selectedId = id;
    emit selectedIdChanged();
    fetchFirstPage(id);
}

Conversation *MessageStore::findConversation(const QString &id)
{
    for (Conversation &c : m_conversations)
        if (c.id == id)
            return &c;
    return nullptr;
}

Message *MessageStore::findMessage(const QString &messageId)
{
    for (Thread &t : m_threads)
        for (Message &m : t.messages)
            if (m.id == messageId)
                return &m;
    return nullptr;
}

QVariant MessageStore::conversationById(const QString &id, const QVariant &) const
{
    for (const Conversation &c : m_conversations)
        if (c.id == id)
            return QVariant::fromValue(c);
    return QVariant::fromValue(nullptr);
}

QVariant MessageStore::currentConversation(const QVariant &) const
{
    for (const Conversation &c : m_conversations)
        if (c.open)
            return QVariant::fromValue(c);
    return QVariant::fromValue(nullptr);
}

QList<Conversation> MessageStore::conversations() const
{
    QList<Conversation> list = m_conversations;
    for (Conversation &c : list) {
        if (!c.lastMine)
            continue;
        // The last message may still be on its way (or failed): unsent ones are last
        const auto thread = m_threads.constFind(c.id);
        if (thread != m_threads.cend() && !thread->messages.isEmpty()
            && thread->messages.constLast().mine && thread->messages.constLast().pending())
            c.lastReceipt = thread->messages.constLast().status;
        else
            c.lastReceipt = receiptAt(c.lastAt, c);
    }
    return list;
}

QList<Message> MessageStore::messages(const QString &id, const QVariant &) const
{
    QList<Message> list = m_threads.value(id).messages;
    Conversation none;
    const Conversation *c = &none;
    for (const Conversation &x : m_conversations)
        if (x.id == id)
            c = &x;
    for (Message &m : list)
        m.receipt = !m.mine ? QString() : m.pending() ? m.status : receiptAt(m.createdAt, *c);
    return list;
}

QString MessageStore::receiptAt(double at, const Conversation &c)
{
    if (at > 0 && c.otherReadAt >= at)
        return QStringLiteral("read");
    if (at > 0 && c.otherDeliveredAt >= at)
        return QStringLiteral("delivered");
    return QStringLiteral("sent");
}

bool MessageStore::isFetching(const QString &id, const QVariant &) const
{
    const auto it = m_threads.constFind(id);
    return it != m_threads.cend() && it->fetching && !it->fetched;
}

bool MessageStore::hasOlder(const QString &id, const QVariant &) const
{
    return m_threads.value(id).hasOlder;
}

QString MessageStore::newestIso(const Thread &thread) const
{
    for (auto it = thread.messages.crbegin(); it != thread.messages.crend(); ++it)
        if (!it->pending())
            return it->createdAtIso;
    return {};
}

void MessageStore::sortConversations()
{
    std::stable_sort(m_conversations.begin(), m_conversations.end(), [](const Conversation &a, const Conversation &b) {
        if (a.open != b.open)
            return a.open;
        if (a.lastAt != b.lastAt)
            return a.lastAt > b.lastAt;
        return QString::localeAwareCompare(a.otherName, b.otherName) < 0;
    });
}

// ---- times ----------------------------------------------------------------------

QString MessageStore::clockTime(double ms) const
{
    if (ms <= 0)
        return {};
    return QLocale().toString(QDateTime::fromMSecsSinceEpoch(qint64(ms)).time(), QLocale::ShortFormat);
}

QString MessageStore::listTime(double ms) const
{
    if (ms <= 0)
        return {};
    const QDate day = localDate(ms);
    const QDate today = QDate::currentDate();
    if (day == today)
        return clockTime(ms);
    if (day == today.addDays(-1))
        return tr("Yesterday");
    if (day > today.addDays(-7))
        return QLocale().dayName(day.dayOfWeek(), QLocale::ShortFormat);
    return QLocale().toString(day, day.year() == today.year() ? QStringLiteral("d MMM") : QStringLiteral("d MMM yyyy"));
}

QString MessageStore::dayLabel(double ms) const
{
    const QDate day = localDate(ms);
    const QDate today = QDate::currentDate();
    if (day == today)
        return tr("Today");
    if (day == today.addDays(-1))
        return tr("Yesterday");
    return QLocale().toString(day, day.year() == today.year() ? QStringLiteral("dddd d MMMM")
                                                               : QStringLiteral("d MMMM yyyy"));
}

bool MessageStore::sameDay(double a, double b) const
{
    return localDate(a) == localDate(b);
}

// ---- changes --------------------------------------------------------------------

void MessageStore::open(const QString &id)
{
    setSelectedId(id);
    fetchFirstPage(id);
}

void MessageStore::send(const QString &id, const QString &body)
{
    const QString text = body.trimmed();
    if (text.isEmpty())
        return;
    if (text.size() > kMaxLength) {
        emit errorOccurred(errorText(QStringLiteral("invalid_length")));
        return;
    }
    Conversation *conversation = findConversation(id);
    if (!conversation || !conversation->open) {
        emit errorOccurred(errorText(QStringLiteral("conversation_closed")));
        return;
    }

    Message m;
    m.id = newId();
    m.coachingId = id;
    m.senderId = userId();
    m.body = text;
    m.createdAt = double(QDateTime::currentMSecsSinceEpoch());
    m.mine = true;
    m.status = QStringLiteral("sending");
    m_threads[id].messages.append(m);

    conversation->lastBody = text;
    conversation->lastAt = m.createdAt;
    conversation->lastMine = true;
    sortConversations();
    changed();
    sendNow(m.id);
}

void MessageStore::sendNow(const QString &messageId)
{
    Message *m = findMessage(messageId);
    if (!m)
        return;
    m->status = QStringLiteral("sending");
    const QJsonObject args{{QStringLiteral("p_coaching"), m->coachingId},
                           {QStringLiteral("p_body"), m->body},
                           {QStringLiteral("p_id"), m->id}};
    write([this, args, messageId](SupabaseClient::Callback done) {
        m_client->rpc(this, QStringLiteral("send_message"), args,
                      [this, messageId, done](const SupabaseClient::Reply &reply) {
                          if (Message *msg = findMessage(messageId)) {
                              if (reply.ok()) {
                                  const QJsonObject row = reply.data.isArray()
                                                              ? reply.data.array().first().toObject()
                                                              : reply.data.object();
                                  auto it = m_threads.find(msg->coachingId);
                                  if (it != m_threads.end())
                                      merge(*it, QJsonArray{row});
                              } else {
                                  msg->status = QStringLiteral("failed");
                              }
                              changed();
                          }
                          done(reply);
                      });
    });
}

void MessageStore::retry(const QString &messageId)
{
    const Message *m = findMessage(messageId);
    if (!m || m->status != QLatin1String("failed"))
        return;
    sendNow(messageId);
    changed();
}

void MessageStore::discard(const QString &messageId)
{
    for (Thread &t : m_threads) {
        const auto removed = t.messages.removeIf([&](const Message &m) {
            return m.id == messageId && m.status == QLatin1String("failed");
        });
        if (removed > 0) {
            changed();
            return;
        }
    }
}

void MessageStore::markDelivered()
{
    for (Conversation &c : m_conversations) {
        if (c.otherLastAtIso.isEmpty() || c.otherLastAt <= c.myDeliveredAt)
            continue;
        // Up to the newest message the app has, not "now": one that arrives
        // meanwhile isn't marked before the app gets it
        c.myDeliveredAt = c.otherLastAt;
        writeRpc(QStringLiteral("mark_delivered"),
                 {{QStringLiteral("p_coaching"), c.id}, {QStringLiteral("p_until"), c.otherLastAtIso}});
    }
}

void MessageStore::markRead(const QString &id)
{
    Conversation *c = findConversation(id);
    if (!c || c->unread == 0)
        return;
    // Up to the newest message the user has (the list's or the conversation's)
    QString until = c->lastAtIso;
    double untilMs = c->lastAt;
    const auto it = m_threads.constFind(id);
    if (it != m_threads.cend()) {
        for (auto m = it->messages.crbegin(); m != it->messages.crend(); ++m) {
            if (!m->pending()) {
                if (m->createdAt > untilMs) {
                    until = m->createdAtIso;
                    untilMs = m->createdAt;
                }
                break;
            }
        }
    }
    if (until.isEmpty())
        return;
    c->unread = 0;
    changed();
    writeRpc(QStringLiteral("mark_read"), {{QStringLiteral("p_coaching"), id}, {QStringLiteral("p_until"), until}});
}
