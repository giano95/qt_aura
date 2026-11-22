// See session.h.
#include "session.h"

#include "supabaseclient.h"

#include <QJsonArray>
#include <QRegularExpression>
#include <QUrlQuery>

Session::Session(QObject *parent)
    : QObject(parent)
    , m_client(SupabaseClient::instance())
{
    connect(m_client, &SupabaseClient::sessionExpired, this, [this] {
        if (!loggedIn())
            return;
        setUser({});
        setLastError(tr("Your session has expired. Log in again."));
    });
}

QString Session::firstName() const
{
    return loggedIn() ? m_user.name.section(QLatin1Char(' '), 0, 0) : QString();
}

void Session::login(const QString &email, const QString &password)
{
    if (m_busy)
        return;
    setLastError({});
    setBusy(true);
    m_client->signIn(this, email.trimmed().toLower(), password,
                     [this](const SupabaseClient::Reply &reply) {
                         if (!reply.ok()) {
                             fail(errorText(reply.errorCode));
                             return;
                         }
                         loadProfile();
                     });
}

void Session::signup(const QString &name, const QString &email, const QString &password,
                     const QString &role)
{
    if (m_busy)
        return;
    setLastError({});
    setBusy(true);
    const QJsonObject metadata{{QStringLiteral("name"), name.trimmed()}, {QStringLiteral("role"), role}};
    m_client->signUp(this, email.trimmed().toLower(), password, metadata,
                     [this](const SupabaseClient::Reply &reply) {
                         if (!reply.ok()) {
                             fail(errorText(reply.errorCode));
                             return;
                         }
                         if (!m_client->hasSession()) {
                             // Email confirmation is on in the Supabase project
                             fail(tr("Check your inbox to confirm your email, then log in."));
                             return;
                         }
                         loadProfile();
                     });
}

void Session::logout()
{
    m_client->signOut();
    setUser({});
}

void Session::clearError()
{
    setLastError({});
}

bool Session::isValidEmail(const QString &email) const
{
    static const QRegularExpression pattern(QStringLiteral(R"(^[^\s@]+@[^\s@]+\.[^\s@]+$)"));
    return pattern.match(email.trimmed()).hasMatch();
}

// The profile row says who the user is (name, coach or client)
void Session::loadProfile()
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("select"), QStringLiteral("id,name,email,role"));
    query.addQueryItem(QStringLiteral("id"), QStringLiteral("eq.") + m_client->userId());
    m_client->select(this, QStringLiteral("profiles"), query, [this](const SupabaseClient::Reply &reply) {
        const QJsonArray rows = reply.data.array();
        if (!reply.ok() || rows.isEmpty()) {
            m_client->signOut();
            fail(reply.ok() ? tr("This account has no profile. Please contact support.")
                            : errorText(reply.errorCode));
            return;
        }
        setBusy(false);
        setUser(AuraUser::fromJson(rows.first().toObject()));
    });
}

void Session::fail(const QString &message)
{
    setBusy(false);
    setLastError(message);
}

QString Session::errorText(const QString &code)
{
    if (code == QLatin1String("invalid_credentials"))
        return tr("Incorrect email or password.");
    if (code == QLatin1String("user_already_exists") || code == QLatin1String("email_exists"))
        return tr("An account with this email already exists. Try logging in.");
    if (code == QLatin1String("email_not_confirmed"))
        return tr("Confirm your email first: check your inbox.");
    if (code == QLatin1String("weak_password"))
        return tr("Choose a stronger password.");
    if (code == QLatin1String("email_address_invalid"))
        return tr("Enter a valid email address.");
    if (code.startsWith(QLatin1String("over_")) && code.endsWith(QLatin1String("rate_limit")))
        return tr("Too many attempts. Wait a minute and try again.");
    if (code == QLatin1String("network"))
        return tr("Can't reach the server. Check your internet connection.");
    return tr("Something went wrong (%1). Please try again.").arg(code);
}

void Session::setUser(const AuraUser &user)
{
    if (m_user == user)
        return;
    m_user = user;
    emit userChanged();
}

void Session::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void Session::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}
