// Talks to the Supabase backend over HTTPS: email/password auth (with token
// refresh), PostgREST table reads/writes and RPC calls to the SQL functions in
// supabase/migrations. Only Qt Network, so it works the same on every platform.
//
// One instance lives for the whole app (created in main.cpp); stores reach it
// through SupabaseClient::instance(). Every request takes a `context` QObject:
// if the context is destroyed before the reply arrives, the callback is skipped.
#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QUrlQuery>

#include <functional>

class QNetworkReply;

class SupabaseClient : public QObject
{
    Q_OBJECT

public:
    struct Reply
    {
        int status = 0;            // HTTP status, 0 when the server wasn't reached
        QJsonDocument data;        // parsed body (array for selects, object for most others)
        // Machine-readable error, empty on success:
        //   "network"         the server couldn't be reached
        //   auth errors       Supabase Auth's error_code ("invalid_credentials", ...)
        //   rule violations   the code our SQL functions raise ("slot_unavailable", ...)
        //   other             the PostgREST/Postgres code, or "http_<status>"
        QString errorCode;
        QString message;           // server's description, for logs only (not translated)

        bool ok() const { return errorCode.isEmpty(); }
    };
    using Callback = std::function<void(const Reply &)>;

    SupabaseClient(const QString &baseUrl, const QString &apiKey, QObject *parent = nullptr);
    ~SupabaseClient() override;

    static SupabaseClient *instance();

    // ---- auth ---------------------------------------------------------------
    bool hasSession() const { return !m_accessToken.isEmpty(); }
    QString userId() const { return m_userId; }

    void signIn(QObject *context, const QString &email, const QString &password, Callback done);
    // metadata becomes raw_user_meta_data ({name, role}); the signup trigger
    // creates the profile from it
    void signUp(QObject *context, const QString &email, const QString &password,
                const QJsonObject &metadata, Callback done);
    void signOut();

    // ---- data (as the signed-in user) ---------------------------------------
    // GET /rest/v1/<table>?<query>, e.g. query "select=id,name" + "id=eq.<uuid>"
    void select(QObject *context, const QString &table, const QUrlQuery &query, Callback done);
    void insert(QObject *context, const QString &table, const QJsonValue &rows, Callback done);
    void update(QObject *context, const QString &table, const QUrlQuery &filter,
                const QJsonObject &values, Callback done);
    void remove(QObject *context, const QString &table, const QUrlQuery &filter, Callback done);
    // POST /rest/v1/rpc/<function>
    void rpc(QObject *context, const QString &function, const QJsonObject &args, Callback done);

signals:
    void sessionChanged();
    // The refresh token was rejected: the user has to log in again
    void sessionExpired();

private:
    enum class Auth { Anonymous, User };

    void send(const QByteArray &verb, const QString &path, const QUrlQuery &query,
              const QByteArray &body, Auth auth, QObject *context, Callback done,
              bool retried = false);
    static Reply parseReply(QNetworkReply *reply);

    void setSession(const QJsonObject &tokenResponse);
    void clearSession();
    void refreshSession(std::function<void(bool)> done = {});
    void finishRefresh(bool ok);

    QNetworkAccessManager m_network;
    QString m_baseUrl;
    QString m_apiKey;

    QString m_accessToken;
    QString m_refreshToken;
    QString m_userId;
    QTimer m_refreshTimer;
    bool m_refreshing = false;
    QList<std::function<void(bool)>> m_refreshWaiters;
};
