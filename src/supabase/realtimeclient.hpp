// Live updates from Supabase Realtime, turned into Qt signals.
//
// While a user is logged in, keeps a WebSocket open to Supabase Realtime and
// joins the private channel "user:<profile id>". Database triggers
// (supabase/migrations/*_live_updates.sql) send a "changed" message there
// with only the table name; this class passes it on as
// SupabaseClient::notifyChanged(table), and the stores that watch that table
// reload (StoreBase). After a dropped connection it reconnects and asks every
// store to reload ("*"), since messages sent meanwhile are lost.
//
// Protocol: Phoenix channels, Realtime protocol 1.0.0 (JSON text frames), see
// https://supabase.com/docs/guides/realtime/protocol
#pragma once

#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QWebSocket>

class SupabaseClient;

class RealtimeClient : public QObject
{
    Q_OBJECT

public:
    explicit RealtimeClient(SupabaseClient *client, QObject *parent = nullptr);
    ~RealtimeClient() override;

    // Joined the user's channel: changes arrive live
    bool isLive() const { return m_joined; }

signals:
    void liveChanged();

private:
    void onSessionChanged();
    void open();
    void close();
    void onConnected();
    void onDisconnected();
    void onMessage(const QString &text);
    void join();
    void sendHeartbeat();
    void scheduleReconnect();
    void setJoined(bool joined);
    QString push(const QString &topic, const QString &event, const QJsonObject &payload, bool withJoinRef);

    SupabaseClient *m_client;
    QWebSocket m_socket;
    QTimer m_heartbeat;
    QTimer m_reconnect;
    QString m_user;             // whose channel is open, "" when closed
    QString m_topic;
    QString m_token;            // token the channel was last given
    QString m_joinRef;
    QString m_pendingHeartbeat; // ref of a heartbeat without a reply yet
    int m_ref = 0;
    int m_attempt = 0;
    bool m_joined = false;
    bool m_hadJoined = false;   // joined before on this login: a rejoin needs a resync
};
