// Messages between a coach and their clients (QML singleton `MessageStore`),
// from the `conversations()` function and the `messages` table.
//
// One conversation per coaching. Both sides can write while the coaching is
// active or paused; an ended coaching's conversation stays readable. A
// conversation's messages are fetched when it is opened (the newest 50, older
// ones on request); after that, a live update fetches only what's new.
//
// Sending shows the message at once ("sending"); if the server refuses it, it
// stays as "failed" and can be sent again (same id, so never twice).
//
// Ticks on the user's own messages (`receipt`) come from how far the other
// person's app has received (delivered) and how far they have read. This app
// records "received" for the other person's newest message each time it loads
// the conversations, and "read" while the chat is on screen.
//
// Bindings that call a function reading store data pass `revision` last
// (see StoreBase), e.g. MessageStore.messages(id, MessageStore.revision).
#pragma once

#include "message.hpp"
#include "storebase.hpp"

#include <QHash>
#include <QJsonArray>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class MessageStore : public StoreBase
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Open conversations first, then ended ones; each by last message, newest first
    Q_PROPERTY(QList<Conversation> conversations READ conversations NOTIFY revisionChanged FINAL)
    // Unread messages in all conversations (menu badge)
    Q_PROPERTY(int unreadTotal READ unreadTotal NOTIFY revisionChanged FINAL)
    // The conversation shown on the Messages page ("" = none)
    Q_PROPERTY(QString selectedId READ selectedId WRITE setSelectedId NOTIFY selectedIdChanged FINAL)

public:
    explicit MessageStore(QObject *parent = nullptr);

    QList<Conversation> conversations() const;
    int unreadTotal() const;
    QString selectedId() const { return m_selectedId; }
    void setSelectedId(const QString &id);

    // ---- reading (pass `revision` last from bindings) -------------------------
    // The conversation, or null
    Q_INVOKABLE QVariant conversationById(const QString &id, const QVariant &revision = {}) const;
    // The open conversation with the client's current coach, or null
    Q_INVOKABLE QVariant currentConversation(const QVariant &revision = {}) const;
    // Loaded messages of a conversation, oldest first
    Q_INVOKABLE QList<Message> messages(const QString &id, const QVariant &revision = {}) const;
    // The first fetch of the conversation's messages is still running
    Q_INVOKABLE bool isFetching(const QString &id, const QVariant &revision = {}) const;
    // There are older messages than the loaded ones
    Q_INVOKABLE bool hasOlder(const QString &id, const QVariant &revision = {}) const;

    // "14:05" today, "Yesterday", a weekday within a week, else a date
    Q_INVOKABLE QString listTime(double ms) const;
    // "14:05"
    Q_INVOKABLE QString clockTime(double ms) const;
    // "Today", "Yesterday", "Monday 24 November", "24 November 2025"
    Q_INVOKABLE QString dayLabel(double ms) const;
    // Same local day
    Q_INVOKABLE bool sameDay(double a, double b) const;

    // ---- changes --------------------------------------------------------------------
    // Selects the conversation and fetches its messages if needed
    Q_INVOKABLE void open(const QString &id);
    Q_INVOKABLE void loadOlder(const QString &id);
    // Sends a text message (trimmed; 1–4000 characters)
    Q_INVOKABLE void send(const QString &id, const QString &body);
    // Sends a failed message again / removes it
    Q_INVOKABLE void retry(const QString &messageId);
    Q_INVOKABLE void discard(const QString &messageId);
    // Marks the conversation read up to its newest message
    Q_INVOKABLE void markRead(const QString &id);

signals:
    void selectedIdChanged();
    // A new message from the other person arrived (seen on a live update)
    void messageReceived(const QString &conversationId, const QString &senderName, const QString &body);

protected:
    void load() override;
    bool clearData() override;
    QString errorText(const QString &code) const override;

private:
    struct Thread
    {
        QList<Message> messages;    // oldest first; unsent ones last
        bool fetched = false;       // the first page arrived
        bool fetching = false;
        bool hasOlder = false;
        bool loadingOlder = false;
    };

    Conversation *findConversation(const QString &id);
    Message *findMessage(const QString &messageId);
    void fetchFirstPage(const QString &id);
    // Adds server rows to a thread (skips the ones it has, replaces unsent copies)
    void merge(Thread &thread, const QJsonArray &rows);
    void sortConversations();
    void sendNow(const QString &messageId);
    QString newestIso(const Thread &thread) const;
    // Ticks of the user's message sent at `at` (server time)
    static QString receiptAt(double at, const Conversation &c);
    // Tells the server this app has the other person's newest messages
    void markDelivered();

    QList<Conversation> m_conversations;
    QHash<QString, Thread> m_threads;
    QString m_selectedId;
    bool m_loadedOnce = false;
    int m_epoch = 0;            // bumped on logout: late replies are ignored
};
