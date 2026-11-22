// See supabaseclient.h.
#include "supabaseclient.h"

#include <QJsonArray>
#include <QLoggingCategory>
#include <QNetworkReply>
#include <QNetworkRequest>

#include <utility>

Q_LOGGING_CATEGORY(lcSupabase, "aura.supabase")

namespace {

SupabaseClient *s_instance = nullptr;

constexpr int kTransferTimeoutMs = 15000;
// Refresh the access token this long before it expires
constexpr int kRefreshMarginSeconds = 60;
// Retry delay when a refresh fails because the network is down
constexpr int kRefreshRetryMs = 30000;

QByteArray toJson(const QJsonValue &value)
{
    if (value.isArray())
        return QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact);
    return QJsonDocument(value.toObject()).toJson(QJsonDocument::Compact);
}

} // namespace

SupabaseClient::SupabaseClient(const QString &baseUrl, const QString &apiKey, QObject *parent)
    : QObject(parent)
    , m_baseUrl(baseUrl)
    , m_apiKey(apiKey)
{
    Q_ASSERT(!s_instance);
    s_instance = this;
    m_refreshTimer.setSingleShot(true);
    connect(&m_refreshTimer, &QTimer::timeout, this, [this] { refreshSession(); });
}

SupabaseClient::~SupabaseClient()
{
    if (s_instance == this)
        s_instance = nullptr;
}

SupabaseClient *SupabaseClient::instance()
{
    Q_ASSERT_X(s_instance, "SupabaseClient::instance", "create the client in main() first");
    return s_instance;
}

// ---- auth -------------------------------------------------------------------

void SupabaseClient::signIn(QObject *context, const QString &email, const QString &password,
                            Callback done)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("password"));
    const QJsonObject body{{QStringLiteral("email"), email}, {QStringLiteral("password"), password}};
    send("POST", QStringLiteral("/auth/v1/token"), query, toJson(body), Auth::Anonymous, context,
         [this, done](const Reply &reply) {
             if (reply.ok())
                 setSession(reply.data.object());
             done(reply);
         });
}

void SupabaseClient::signUp(QObject *context, const QString &email, const QString &password,
                            const QJsonObject &metadata, Callback done)
{
    const QJsonObject body{{QStringLiteral("email"), email},
                           {QStringLiteral("password"), password},
                           {QStringLiteral("data"), metadata}};
    send("POST", QStringLiteral("/auth/v1/signup"), {}, toJson(body), Auth::Anonymous, context,
         [this, done](const Reply &reply) {
             // With email confirmation off the reply carries a session; with it
             // on, only the user (no access_token) until the email is confirmed
             if (reply.ok() && reply.data.object().contains(QStringLiteral("access_token")))
                 setSession(reply.data.object());
             done(reply);
         });
}

void SupabaseClient::signOut()
{
    if (hasSession()) {
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("scope"), QStringLiteral("local"));
        // Fire and forget: the tokens are dropped locally either way
        send("POST", QStringLiteral("/auth/v1/logout"), query, {}, Auth::User, this, [](const Reply &) {});
    }
    clearSession();
}

void SupabaseClient::setSession(const QJsonObject &tokenResponse)
{
    m_accessToken = tokenResponse.value(QStringLiteral("access_token")).toString();
    m_refreshToken = tokenResponse.value(QStringLiteral("refresh_token")).toString();
    m_userId = tokenResponse.value(QStringLiteral("user")).toObject().value(QStringLiteral("id")).toString();
    const int expiresIn = tokenResponse.value(QStringLiteral("expires_in")).toInt(3600);
    m_refreshTimer.start(qMax(10, expiresIn - kRefreshMarginSeconds) * 1000);
    emit sessionChanged();
}

void SupabaseClient::clearSession()
{
    const bool had = hasSession();
    m_accessToken.clear();
    m_refreshToken.clear();
    m_userId.clear();
    m_refreshTimer.stop();
    if (had)
        emit sessionChanged();
}

void SupabaseClient::refreshSession(std::function<void(bool)> done)
{
    if (done)
        m_refreshWaiters.append(std::move(done));
    if (m_refreshing)
        return;
    if (m_refreshToken.isEmpty()) {
        finishRefresh(false);
        return;
    }
    m_refreshing = true;
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));
    const QJsonObject body{{QStringLiteral("refresh_token"), m_refreshToken}};
    send("POST", QStringLiteral("/auth/v1/token"), query, toJson(body), Auth::Anonymous, this,
         [this](const Reply &reply) {
             m_refreshing = false;
             if (reply.ok()) {
                 setSession(reply.data.object());
                 finishRefresh(true);
                 return;
             }
             if (reply.errorCode == QLatin1String("network")) {
                 // Keep the session; try again later
                 m_refreshTimer.start(kRefreshRetryMs);
             } else {
                 qCWarning(lcSupabase) << "session refresh rejected:" << reply.errorCode << reply.message;
                 clearSession();
                 emit sessionExpired();
             }
             finishRefresh(false);
         });
}

void SupabaseClient::finishRefresh(bool ok)
{
    const auto waiters = std::exchange(m_refreshWaiters, {});
    for (const auto &waiter : waiters)
        waiter(ok);
}

// ---- data -------------------------------------------------------------------

void SupabaseClient::select(QObject *context, const QString &table, const QUrlQuery &query, Callback done)
{
    send("GET", QStringLiteral("/rest/v1/") + table, query, {}, Auth::User, context, std::move(done));
}

void SupabaseClient::insert(QObject *context, const QString &table, const QJsonValue &rows, Callback done)
{
    send("POST", QStringLiteral("/rest/v1/") + table, {}, toJson(rows), Auth::User, context, std::move(done));
}

void SupabaseClient::update(QObject *context, const QString &table, const QUrlQuery &filter,
                            const QJsonObject &values, Callback done)
{
    send("PATCH", QStringLiteral("/rest/v1/") + table, filter, toJson(values), Auth::User, context,
         std::move(done));
}

void SupabaseClient::remove(QObject *context, const QString &table, const QUrlQuery &filter, Callback done)
{
    send("DELETE", QStringLiteral("/rest/v1/") + table, filter, {}, Auth::User, context, std::move(done));
}

void SupabaseClient::rpc(QObject *context, const QString &function, const QJsonObject &args, Callback done)
{
    send("POST", QStringLiteral("/rest/v1/rpc/") + function, {}, toJson(args), Auth::User, context,
         std::move(done));
}

// ---- transport ----------------------------------------------------------------

void SupabaseClient::send(const QByteArray &verb, const QString &path, const QUrlQuery &query,
                          const QByteArray &body, Auth auth, QObject *context, Callback done,
                          bool retried)
{
    QUrl url(m_baseUrl + path);
    url.setQuery(query);
    QNetworkRequest request(url);
    request.setRawHeader("apikey", m_apiKey.toUtf8());
    request.setHeader(QNetworkRequest::ContentTypeHeader, QByteArrayLiteral("application/json"));
    if (auth == Auth::User && hasSession())
        request.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());
    request.setTransferTimeout(kTransferTimeoutMs);

    QNetworkReply *reply = m_network.sendCustomRequest(request, verb, body);
    const QPointer<QObject> guard(context);
    const bool hasContext = context != nullptr;
    connect(reply, &QNetworkReply::finished, this,
            [=, this, done = std::move(done)]() {
                reply->deleteLater();
                if (hasContext && !guard)
                    return;
                const Reply result = parseReply(reply);
                // Access token expired early (clock skew, sleep): refresh once and retry
                if (result.status == 401 && auth == Auth::User && !retried && !m_refreshToken.isEmpty()) {
                    refreshSession([=, this](bool ok) {
                        if (hasContext && !guard)
                            return;
                        if (ok)
                            send(verb, path, query, body, auth, guard.data(), done, true);
                        else
                            done(result);
                    });
                    return;
                }
                if (!result.ok())
                    qCWarning(lcSupabase) << verb << path << result.status << result.errorCode << result.message;
                done(result);
            });
}

SupabaseClient::Reply SupabaseClient::parseReply(QNetworkReply *reply)
{
    Reply result;
    result.status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    result.data = QJsonDocument::fromJson(reply->readAll());

    if (result.status == 0) {
        result.errorCode = QStringLiteral("network");
        result.message = reply->errorString();
        return result;
    }
    if (result.status < 400)
        return result;

    const QJsonObject error = result.data.object();
    const QString code = error.value(QStringLiteral("code")).isString()
                             ? error.value(QStringLiteral("code")).toString() : QString();
    if (error.contains(QStringLiteral("error_code"))) {
        // Supabase Auth: {code: 400, error_code: "invalid_credentials", msg: "..."}
        result.errorCode = error.value(QStringLiteral("error_code")).toString();
    } else if (code == QLatin1String("P0001")) {
        // `raise exception 'slot_unavailable'` in our SQL functions
        result.errorCode = error.value(QStringLiteral("message")).toString();
    } else if (!code.isEmpty()) {
        result.errorCode = code;
    } else if (error.contains(QStringLiteral("error"))) {
        result.errorCode = error.value(QStringLiteral("error")).toString();
    }
    if (result.errorCode.isEmpty())
        result.errorCode = QStringLiteral("http_%1").arg(result.status);

    result.message = error.value(QStringLiteral("msg")).toString(
        error.value(QStringLiteral("message")).toString(
            error.value(QStringLiteral("error_description")).toString()));
    return result;
}
