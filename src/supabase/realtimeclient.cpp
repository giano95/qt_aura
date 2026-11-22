// See realtimeclient.hpp.
#include "realtimeclient.hpp"

#include "supabaseclient.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QLoggingCategory>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>

Q_LOGGING_CATEGORY(lcRealtime, "aura.realtime")

namespace {
// Realtime closes connections without a heartbeat for about 30 s
constexpr int heartbeatMs = 25000;
// Waits before reconnecting: 1 s, 2 s, 5 s, 10 s, then every 30 s
constexpr int reconnectDelays[] = {1000, 2000, 5000, 10000, 30000};
} // namespace

RealtimeClient::RealtimeClient(SupabaseClient *client, QObject *parent)
    : QObject(parent)
    , m_client(client)
{
    m_heartbeat.setInterval(heartbeatMs);
    connect(&m_heartbeat, &QTimer::timeout, this, &RealtimeClient::sendHeartbeat);
    m_reconnect.setSingleShot(true);
    connect(&m_reconnect, &QTimer::timeout, this, &RealtimeClient::open);

    connect(&m_socket, &QWebSocket::connected, this, &RealtimeClient::onConnected);
    connect(&m_socket, &QWebSocket::disconnected, this, &RealtimeClient::onDisconnected);
    connect(&m_socket, &QWebSocket::textMessageReceived, this, &RealtimeClient::onMessage);
    connect(&m_socket, &QWebSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        qCInfo(lcRealtime) << "socket error:" << m_socket.errorString();
    });

    connect(m_client, &SupabaseClient::sessionChanged, this, &RealtimeClient::onSessionChanged);
    onSessionChanged();
}

RealtimeClient::~RealtimeClient()
{
    // Don't react to the socket closing while being destroyed
    m_socket.disconnect(this);
    m_socket.abort();
}

void RealtimeClient::onSessionChanged()
{
    if (!m_client->hasSession()) {
        close();
        return;
    }
    if (m_client->userId() != m_user) {
        // Another user: start over on their channel
        close();
        m_user = m_client->userId();
        m_topic = QStringLiteral("realtime:user:") + m_user;
        open();
        return;
    }
    // Same user, refreshed token: the channel needs it before the old one expires
    if (m_joined && m_client->accessToken() != m_token) {
        m_token = m_client->accessToken();
        push(m_topic, QStringLiteral("access_token"), {{QStringLiteral("access_token"), m_token}}, true);
    }
}

void RealtimeClient::open()
{
    if (m_user.isEmpty() || m_socket.state() != QAbstractSocket::UnconnectedState)
        return;
    QUrl url(m_client->baseUrl());
    url.setScheme(url.scheme() == QLatin1String("http") ? QStringLiteral("ws") : QStringLiteral("wss"));
    url.setPath(QStringLiteral("/realtime/v1/websocket"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("apikey"), m_client->apiKey());
    query.addQueryItem(QStringLiteral("vsn"), QStringLiteral("1.0.0"));
    url.setQuery(query);
    qCInfo(lcRealtime) << "connecting";
    m_socket.open(url);
}

void RealtimeClient::close()
{
    m_reconnect.stop();
    m_heartbeat.stop();
    m_user.clear();
    m_topic.clear();
    m_token.clear();
    m_pendingHeartbeat.clear();
    m_attempt = 0;
    m_hadJoined = false;
    setJoined(false);
    if (m_socket.state() != QAbstractSocket::UnconnectedState)
        m_socket.close();
}

void RealtimeClient::onConnected()
{
    qCInfo(lcRealtime) << "connected";
    m_pendingHeartbeat.clear();
    m_heartbeat.start();
    join();
}

void RealtimeClient::onDisconnected()
{
    m_heartbeat.stop();
    setJoined(false);
    if (m_user.isEmpty())
        return;     // logged out on purpose
    qCInfo(lcRealtime) << "disconnected:" << m_socket.closeReason();
    scheduleReconnect();
}

void RealtimeClient::scheduleReconnect()
{
    if (m_user.isEmpty() || m_reconnect.isActive())
        return;
    const int last = int(std::size(reconnectDelays)) - 1;
    m_reconnect.start(reconnectDelays[std::min(m_attempt, last)]);
    ++m_attempt;
}

void RealtimeClient::join()
{
    m_token = m_client->accessToken();
    const QJsonObject config{
        {QStringLiteral("broadcast"), QJsonObject{{QStringLiteral("ack"), false}, {QStringLiteral("self"), false}}},
        {QStringLiteral("presence"), QJsonObject{{QStringLiteral("enabled"), false}}},
        {QStringLiteral("postgres_changes"), QJsonArray()},
        {QStringLiteral("private"), true}};
    m_joinRef = QString::number(++m_ref);
    QJsonObject message{{QStringLiteral("topic"), m_topic},
                        {QStringLiteral("event"), QStringLiteral("phx_join")},
                        {QStringLiteral("payload"), QJsonObject{{QStringLiteral("config"), config},
                                                                {QStringLiteral("access_token"), m_token}}},
                        {QStringLiteral("ref"), m_joinRef},
                        {QStringLiteral("join_ref"), m_joinRef}};
    m_socket.sendTextMessage(QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact)));
}

QString RealtimeClient::push(const QString &topic, const QString &event, const QJsonObject &payload, bool withJoinRef)
{
    const QString ref = QString::number(++m_ref);
    QJsonObject message{{QStringLiteral("topic"), topic},
                        {QStringLiteral("event"), event},
                        {QStringLiteral("payload"), payload},
                        {QStringLiteral("ref"), ref}};
    if (withJoinRef)
        message.insert(QStringLiteral("join_ref"), m_joinRef);
    m_socket.sendTextMessage(QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact)));
    return ref;
}

void RealtimeClient::sendHeartbeat()
{
    if (!m_pendingHeartbeat.isEmpty()) {
        // The last one got no reply: the connection is dead even if the OS
        // hasn't noticed (sleep, network change). Reconnect.
        qCInfo(lcRealtime) << "heartbeat timed out";
        m_pendingHeartbeat.clear();
        m_socket.abort();
        return;
    }
    m_pendingHeartbeat = push(QStringLiteral("phoenix"), QStringLiteral("heartbeat"), {}, false);
}

void RealtimeClient::setJoined(bool joined)
{
    if (m_joined == joined)
        return;
    m_joined = joined;
    emit liveChanged();
}

void RealtimeClient::onMessage(const QString &text)
{
    const QJsonObject message = QJsonDocument::fromJson(text.toUtf8()).object();
    const QString topic = message.value(QStringLiteral("topic")).toString();
    const QString event = message.value(QStringLiteral("event")).toString();
    const QString ref = message.value(QStringLiteral("ref")).toString();
    const QJsonObject payload = message.value(QStringLiteral("payload")).toObject();

    if (event == QLatin1String("phx_reply")) {
        const bool ok = payload.value(QStringLiteral("status")).toString() == QLatin1String("ok");
        if (ref == m_pendingHeartbeat) {
            m_pendingHeartbeat.clear();
        } else if (ref == m_joinRef && topic == m_topic) {
            if (!ok) {
                qCWarning(lcRealtime) << "join refused:" << payload.value(QStringLiteral("response")).toObject();
                m_socket.close();     // retried with backoff
                return;
            }
            qCInfo(lcRealtime) << "joined" << topic;
            m_attempt = 0;
            setJoined(true);
            // Messages sent while disconnected are lost: catch up
            if (m_hadJoined)
                m_client->notifyChanged(QStringLiteral("*"), this);
            m_hadJoined = true;
        } else if (!ok) {
            qCWarning(lcRealtime) << "refused:" << payload;
        }
        return;
    }
    if (topic != m_topic)
        return;
    if (event == QLatin1String("broadcast")) {
        const QJsonObject inner = payload.value(QStringLiteral("payload")).toObject();
        const QString table = inner.value(QStringLiteral("table")).toString();
        if (payload.value(QStringLiteral("event")).toString() == QLatin1String("changed") && !table.isEmpty()) {
            qCDebug(lcRealtime) << "changed:" << table;
            m_client->notifyChanged(table, this);
        }
    } else if (event == QLatin1String("phx_error") || event == QLatin1String("phx_close")) {
        // The channel ended (server restart, expired token): rejoin on a new connection
        qCInfo(lcRealtime) << event << "on" << topic;
        setJoined(false);
        if (!m_user.isEmpty())
            m_socket.close();
    } else if (event == QLatin1String("system")) {
        qCInfo(lcRealtime) << "system:" << payload.value(QStringLiteral("message")).toString();
    }
}
