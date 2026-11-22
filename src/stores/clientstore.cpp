// See clientstore.hpp.
#include "clientstore.hpp"

#include "programstore.hpp"
#include "supabaseclient.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QLocale>
#include <QQmlEngine>

#include <algorithm>

ClientStore::ClientStore(QObject *parent)
    : StoreBase(parent)
{
    // Coachings (requests, invitations, leaving), assignments, and sessions
    // (next session)
    start({QStringLiteral("coachings"), QStringLiteral("assignments"), QStringLiteral("sessions")});
}

// ---- loading --------------------------------------------------------------------

void ClientStore::load()
{
    const int generation = beginLoad(2);

    // RLS returns the coach's clients, or the client's own coaching
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("select"),
                       QStringLiteral("id,coach_id,client_id,email,name,phone,goal,status,since,last_check_in,"
                                      "assignments(id,program_id,program_name,weeks,start_date,note,"
                                      "ended_on,end_reason,created_at)"));
    query.addQueryItem(QStringLiteral("status"), QStringLiteral("in.(invited,active,paused)"));
    m_client->select(this, QStringLiteral("coachings"), query,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_clients.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows) {
                             Client c = Client::fromJson(row.toObject());
                             c.nextSession = m_nextSessions.value(c.userId);
                             m_clients.append(c);
                         }
                         changed();
                     });

    // Next confirmed session of each client
    QUrlQuery sessions;
    sessions.addQueryItem(QStringLiteral("select"), QStringLiteral("client_id,starts_at"));
    sessions.addQueryItem(QStringLiteral("status"), QStringLiteral("eq.confirmed"));
    sessions.addQueryItem(QStringLiteral("client_id"), QStringLiteral("not.is.null"));
    sessions.addQueryItem(QStringLiteral("starts_at"),
                          QStringLiteral("gt.") + QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    sessions.addQueryItem(QStringLiteral("order"), QStringLiteral("starts_at.asc"));
    m_client->select(this, QStringLiteral("sessions"), sessions,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok())
                             return;     // not worth an error: the clients still show
                         m_nextSessions.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows) {
                             const QJsonObject o = row.toObject();
                             const QString client = o.value(QStringLiteral("client_id")).toString();
                             if (!m_nextSessions.contains(client))
                                 m_nextSessions.insert(client, AuraDates::fromIsoDateTime(
                                                                   o.value(QStringLiteral("starts_at")).toString()));
                         }
                         for (Client &c : m_clients)
                             c.nextSession = m_nextSessions.value(c.userId);
                         changed();
                     });
}

bool ClientStore::clearData()
{
    m_nextSessions.clear();
    if (m_clients.isEmpty())
        return false;
    m_clients.clear();
    return true;
}

QString ClientStore::errorText(const QString &code) const
{
    if (code == QLatin1String("email_taken"))
        return tr("This email already has a coach or an open invitation.");
    if (code == QLatin1String("not_a_coach"))
        return tr("Only coaches can do this.");
    return StoreBase::errorText(code);
}

Client *ClientStore::find(const QString &id)
{
    for (Client &c : m_clients)
        if (c.id == id)
            return &c;
    return nullptr;
}

// ---- dates ----------------------------------------------------------------------

double ClientStore::today() const
{
    return AuraDates::toMs(todayDate());
}

double ClientStore::dayOffset(int days) const
{
    return AuraDates::toMs(todayDate().addDays(days));
}

double ClientStore::nextMonday() const
{
    const QDate t = todayDate();
    return AuraDates::toMs(t.addDays(8 - t.dayOfWeek()));     // dayOfWeek: Monday = 1
}

double ClientStore::lastDay(const QVariant &assignment) const
{
    return AuraDates::toMs(Assignment::fromVariant(assignment).lastDate());
}

int ClientStore::daysBetween(double fromMs, double toMs) const
{
    return int(std::lround((toMs - fromMs) / 86400000.0));
}

QString ClientStore::formatDay(double ms) const
{
    return QLocale().toString(AuraDates::toDate(ms), QStringLiteral("ddd d MMM"));
}

QString ClientStore::formatDayLong(double ms) const
{
    return QLocale().toString(AuraDates::toDate(ms), QStringLiteral("ddd d MMM yyyy"));
}

QString ClientStore::relativeDay(double ms) const
{
    if (ms == 0)
        return tr("Never");
    const qint64 days = AuraDates::toDate(ms).daysTo(todayDate());
    if (days == 0)
        return tr("Today");
    if (days == 1)
        return tr("Yesterday");
    if (days == -1)
        return tr("Tomorrow");
    if (days > 0)
        return tr("%1 days ago").arg(days);
    return tr("In %1 days").arg(-days);
}

// ---- reading --------------------------------------------------------------------

QVariant ClientStore::clientById(const QString &id, const QVariant &) const
{
    for (const Client &c : m_clients)
        if (c.id == id)
            return QVariant::fromValue(c);
    return QVariant::fromValue(nullptr);
}

QVariant ClientStore::clientByEmail(const QString &email, const QVariant &) const
{
    const QString e = email.trimmed();
    for (const Client &c : m_clients)
        if (c.email.compare(e, Qt::CaseInsensitive) == 0)
            return QVariant::fromValue(c);
    return QVariant::fromValue(nullptr);
}

QVariant ClientStore::currentAssignment(const QVariant &client) const
{
    const auto a = Client::fromVariant(client).currentAssignment();
    return a ? QVariant::fromValue(*a) : QVariant::fromValue(nullptr);
}

QList<Assignment> ClientStore::pastAssignments(const QVariant &client) const
{
    return Client::fromVariant(client).pastAssignments();
}

QVariantMap ClientStore::programStatus(const QVariant &client) const
{
    return Client::fromVariant(client).programStatus(todayDate()).toVariantMap();
}

QString ClientStore::statusText(const QVariant &value) const
{
    const ProgramStatus s = ProgramStatus::fromVariant(value);
    if (s.kind == QLatin1String("none"))
        return tr("No program");
    if (s.kind == QLatin1String("scheduled"))
        return s.daysUntil == 1 ? tr("Starts tomorrow") : tr("Starts in %1 days").arg(s.daysUntil);
    if (s.kind == QLatin1String("expired"))
        return s.daysAgo == 1 ? tr("Expired yesterday") : tr("Expired %1 days ago").arg(s.daysAgo);
    if (s.kind == QLatin1String("endingSoon"))
        return s.daysLeft == 0   ? tr("Ends today")
               : s.daysLeft == 1 ? tr("Ends tomorrow")
                                 : tr("Ends in %1 days").arg(s.daysLeft);
    return tr("Week %1 of %2").arg(s.week).arg(s.assignment ? s.assignment->weeks : 0);
}

QString ClientStore::statusTone(const QVariant &value) const
{
    const QString kind = ProgramStatus::fromVariant(value).kind;
    if (kind == QLatin1String("expired"))
        return QStringLiteral("danger");
    if (kind == QLatin1String("endingSoon"))
        return QStringLiteral("accent");
    if (kind == QLatin1String("none"))
        return QStringLiteral("neutral");
    return QStringLiteral("primary");
}

QString ClientStore::endReasonText(const QString &reason) const
{
    if (reason == QLatin1String("completed"))
        return tr("Completed");
    if (reason == QLatin1String("replaced"))
        return tr("Replaced");
    if (reason == QLatin1String("ended"))
        return tr("Ended early");
    return {};
}

bool ClientStore::matchesFilter(const QVariant &client, const QString &filter) const
{
    return Client::fromVariant(client).matchesFilter(filter, todayDate());
}

QList<Client> ClientStore::search(const QString &query, const QString &filter, const QVariant &) const
{
    const QString q = query.trimmed();
    const QDate t = todayDate();
    QList<Client> result;
    for (const Client &c : m_clients) {
        if (!c.matchesFilter(filter, t))
            continue;
        if (!q.isEmpty()) {
            const auto a = c.currentAssignment();
            if (!c.name.contains(q, Qt::CaseInsensitive) && !c.email.contains(q, Qt::CaseInsensitive)
                && !(a && a->programName.contains(q, Qt::CaseInsensitive)))
                continue;
        }
        result.append(c);
    }
    std::sort(result.begin(), result.end(),
              [](const Client &a, const Client &b) { return QString::localeAwareCompare(a.name, b.name) < 0; });
    return result;
}

int ClientStore::count(const QString &filter, const QVariant &) const
{
    const QDate t = todayDate();
    return int(std::count_if(m_clients.cbegin(), m_clients.cend(),
                             [&](const Client &c) { return c.matchesFilter(filter, t); }));
}

int ClientStore::countForProgram(const QString &programId, const QVariant &) const
{
    if (programId.isEmpty())
        return 0;
    const QDate t = todayDate();
    return int(std::count_if(m_clients.cbegin(), m_clients.cend(), [&](const Client &c) {
        const ProgramStatus s = c.programStatus(t);
        return s.assignment && s.assignment->programId == programId && s.kind != QLatin1String("expired");
    }));
}

bool ClientStore::isEmailTaken(const QString &email, const QVariant &) const
{
    const QString e = email.trimmed();
    return std::any_of(m_clients.cbegin(), m_clients.cend(),
                       [&](const Client &c) { return c.email.compare(e, Qt::CaseInsensitive) == 0; });
}

// ---- changes --------------------------------------------------------------------

void ClientStore::assign(const QString &clientId, const QString &programId, double startMs, const QString &note)
{
    Client *client = find(clientId);
    QQmlEngine *engine = qmlEngine(this);
    auto *programs = engine ? engine->singletonInstance<ProgramStore *>("qt_aura", "ProgramStore") : nullptr;
    if (!client || !programs)
        return;
    const auto list = programs->programs();
    const auto program = std::find_if(list.cbegin(), list.cend(), [&](const Program &p) { return p.id == programId; });
    if (program == list.cend())
        return;

    Assignment a;
    a.id = newId();
    a.programId = program->id;
    a.programName = program->name;
    a.weeks = program->weeks;
    a.start = AuraDates::toMs(AuraDates::toDate(startMs));
    a.note = note.trimmed();
    client->assign(a, todayDate());
    changed();

    writeRpc(QStringLiteral("assign_program"),
        {{QStringLiteral("p_coaching"), clientId},
         {QStringLiteral("p_program"), programId},
         {QStringLiteral("p_start"), a.startDate().toString(Qt::ISODate)},
         {QStringLiteral("p_note"), a.note},
         {QStringLiteral("p_id"), a.id}});
}

void ClientStore::extend(const QString &clientId, int weeks)
{
    Client *client = find(clientId);
    if (!client || !client->extend(weeks))
        return;
    changed();
    writeRpc(QStringLiteral("extend_assignment"), {{QStringLiteral("p_coaching"), clientId}, {QStringLiteral("p_weeks"), weeks}});
}

void ClientStore::endProgram(const QString &clientId)
{
    Client *client = find(clientId);
    if (!client || !client->endProgram(todayDate()))
        return;
    changed();
    writeRpc(QStringLiteral("end_program"), {{QStringLiteral("p_coaching"), clientId}});
}

QString ClientStore::invite(const QString &name, const QString &email, const QString &goal)
{
    Client c;
    c.id = newId();
    c.coachId = userId();
    c.name = name.trimmed();
    c.email = email.trimmed().toLower();
    c.goal = goal.trimmed();
    c.status = QStringLiteral("invited");
    c.since = today();
    m_clients.append(c);
    changed();
    writeRpc(QStringLiteral("invite_client"),
                  {{QStringLiteral("p_name"), c.name},
                   {QStringLiteral("p_email"), c.email},
                   {QStringLiteral("p_goal"), c.goal},
                   {QStringLiteral("p_id"), c.id}},
             [this] { requestLoad(); });    // picks up the account if the email has one
    return c.id;
}
