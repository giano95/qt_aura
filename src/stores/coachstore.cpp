// See coachstore.hpp.
#include "coachstore.hpp"

#include "supabaseclient.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QLocale>

#include <algorithm>

namespace {

QString formatMinutes(int minutes)
{
    if (minutes >= 24 * 60)
        return QStringLiteral("24:00");
    return QStringLiteral("%1:%2").arg(minutes / 60, 2, 10, QLatin1Char('0')).arg(minutes % 60, 2, 10, QLatin1Char('0'));
}

} // namespace

CoachStore::CoachStore(QObject *parent)
    : StoreBase(parent)
{
    // Requests, invitations and links; coaches' hours and profiles
    start({QStringLiteral("coachings"), QStringLiteral("working_hours"), QStringLiteral("coach_profiles")});
}

// ---- loading --------------------------------------------------------------------

void CoachStore::load()
{
    const int generation = beginLoad(2);

    // RLS: public coaches, the user's own coach, the user if they're a coach
    QUrlQuery coaches;
    coaches.addQueryItem(QStringLiteral("select"),
                         QStringLiteral("id,name,email,phone,"
                                        "coach_profiles(title,city,online,in_person,studio,specialties,bio,years,"
                                        "certifications,languages,price_from,accepting,visibility),"
                                        "working_hours(weekday,start_min,end_min)"));
    coaches.addQueryItem(QStringLiteral("role"), QStringLiteral("eq.coach"));
    m_client->select(this, QStringLiteral("profiles"), coaches,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_coaches.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows)
                             m_coaches.append(Coach::fromJson(row.toObject()));
                         changed();
                     });

    // RLS: the coachings on either side of the user
    QUrlQuery links;
    links.addQueryItem(QStringLiteral("select"),
                       QStringLiteral("id,coach_id,client_id,email,name,goal,message,status,since,requested_at"));
    links.addQueryItem(QStringLiteral("status"), QStringLiteral("in.(requested,invited,active,paused,declined)"));
    links.addQueryItem(QStringLiteral("order"), QStringLiteral("requested_at.desc"));
    m_client->select(this, QStringLiteral("coachings"), links,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         const Coaching before = m_relation;
                         Coaching relation;
                         m_requests.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &value : rows) {
                             const QJsonObject row = value.toObject();
                             const Coaching c = Coaching::fromJson(row);
                             if (row.value(QStringLiteral("client_id")).toString() == userId()) {
                                 // At most one open coaching; a decline only shows without one
                                 if (relation.status == QLatin1String("none")
                                     || relation.status == QLatin1String("declined"))
                                     relation = c;
                             } else if (c.status == QLatin1String("pending")) {
                                 m_requests.append(c);
                             }
                         }
                         m_relation = relation;
                         changed();
                         if (before.status == QLatin1String("pending") && relation.status == QLatin1String("active")) {
                             const Coach *coach = findCoach(relation.coachId);
                             emit requestAccepted(coach ? coach->name : QString());
                             notify(QStringLiteral("coachings"));
                         }
                     });
}

bool CoachStore::clearData()
{
    if (m_coaches.isEmpty() && m_requests.isEmpty() && m_relation.status == QLatin1String("none"))
        return false;
    m_coaches.clear();
    m_requests.clear();
    m_relation = Coaching();
    return true;
}

QString CoachStore::errorText(const QString &code) const
{
    if (code == QLatin1String("coach_not_available"))
        return tr("This coach isn't taking new clients right now.");
    if (code == QLatin1String("already_has_coach"))
        return tr("You already have a coach or a request waiting.");
    if (code == QLatin1String("not_a_client"))
        return tr("Only client accounts can do this.");
    if (code == QLatin1String("not_a_coach"))
        return tr("Only coaches can do this.");
    return StoreBase::errorText(code);
}

// ---- reading --------------------------------------------------------------------

bool CoachStore::isCoachAccount() const
{
    return findCoach(userId()) != nullptr;
}

const Coach *CoachStore::findCoach(const QString &id) const
{
    for (const Coach &c : m_coaches)
        if (c.id == id)
            return &c;
    return nullptr;
}

QVariant CoachStore::myRelation() const
{
    if (!m_client->hasSession() || isCoachAccount())
        return QVariant::fromValue(nullptr);
    return QVariant::fromValue(m_relation);
}

QVariant CoachStore::myCoach() const
{
    if (!m_client->hasSession() || isCoachAccount() || m_relation.status == QLatin1String("none"))
        return QVariant::fromValue(nullptr);
    return coachById(m_relation.coachId);
}

QVariant CoachStore::myProfile() const
{
    const Coach *me = findCoach(userId());
    return me ? QVariant::fromValue(*me) : QVariant::fromValue(nullptr);
}

bool CoachStore::isPublic() const
{
    const Coach *me = findCoach(userId());
    return me && me->visibility == QLatin1String("public");
}

QVariant CoachStore::coachById(const QString &id, const QVariant &) const
{
    const Coach *c = findCoach(id);
    return c ? QVariant::fromValue(*c) : QVariant::fromValue(nullptr);
}

QList<Coach> CoachStore::search(const QString &query, const QString &mode, const QVariant &) const
{
    QList<Coach> result;
    for (const Coach &c : m_coaches) {
        if (c.visibility != QLatin1String("public"))
            continue;
        if ((mode == QLatin1String("online") && !c.online) || (mode == QLatin1String("inPerson") && !c.inPerson))
            continue;
        if (c.matches(query))
            result.append(c);
    }
    std::sort(result.begin(), result.end(), [](const Coach &a, const Coach &b) {
        if (a.accepting != b.accepting)
            return a.accepting;
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    return result;
}

QStringList CoachStore::hoursSummary(const QVariant &value) const
{
    const Coach coach = Coach::fromVariant(value);
    const QLocale locale;
    const int order[] = {1, 2, 3, 4, 5, 6, 0};
    // QLocale numbers days Monday = 1 ... Sunday = 7
    const auto shortName = [&](int weekday) { return locale.dayName(weekday == 0 ? 7 : weekday, QLocale::ShortFormat); };
    const auto text = [&](int weekday) {
        QStringList ranges;
        const QVariantList list = coach.weeklyHours.value(QString::number(weekday)).toList();
        for (const QVariant &r : list) {
            const QVariantMap range = r.toMap();
            ranges.append(formatMinutes(range.value(QStringLiteral("start")).toInt()) + QStringLiteral("–")
                          + formatMinutes(range.value(QStringLiteral("end")).toInt()));
        }
        return ranges.join(QStringLiteral(", "));
    };
    QStringList lines;
    int i = 0;
    while (i < 7) {
        const QString t = text(order[i]);
        int j = i;
        while (j + 1 < 7 && text(order[j + 1]) == t)
            ++j;
        if (!t.isEmpty())
            lines.append((i == j ? shortName(order[i]) : shortName(order[i]) + QStringLiteral("–") + shortName(order[j]))
                         + QLatin1Char(' ') + t);
        i = j + 1;
    }
    return lines.isEmpty() ? QStringList{tr("No regular hours set")} : lines;
}

QString CoachStore::modesText(const QVariant &value) const
{
    const Coach coach = Coach::fromVariant(value);
    if (coach.online && coach.inPerson)
        return tr("Online and in person");
    return coach.online ? tr("Online only") : tr("In person only");
}

// ---- changes --------------------------------------------------------------------

void CoachStore::setRelation(const Coaching &relation)
{
    m_relation = relation;
    changed();
}

void CoachStore::rpc(const QString &function, const QJsonObject &args, bool coachingsChanged)
{
    writeRpc(function, args, [this, coachingsChanged] {
        if (coachingsChanged)
            notify(QStringLiteral("coachings"));
    });
}

void CoachStore::request(const QString &coachId, const QString &goal, const QString &message)
{
    Coaching r;
    r.coachId = coachId;
    r.status = QStringLiteral("pending");
    r.since = double(QDateTime::currentMSecsSinceEpoch());
    r.goal = goal.trimmed();
    r.message = message.trimmed();
    setRelation(r);
    writeRpc(QStringLiteral("request_coach"),
                  {{QStringLiteral("p_coach"), coachId},
                   {QStringLiteral("p_goal"), r.goal},
                   {QStringLiteral("p_message"), r.message}},
             [this] { requestLoad(); });    // the request's id
}

void CoachStore::cancelRequest()
{
    setRelation(Coaching());
    rpc(QStringLiteral("cancel_coach_request"), {}, false);
}

void CoachStore::dismissDeclined()
{
    setRelation(Coaching());
    rpc(QStringLiteral("dismiss_declined"), {}, false);
}

void CoachStore::acceptInvitation()
{
    if (m_relation.status != QLatin1String("invited"))
        return;
    Coaching r = m_relation;
    r.status = QStringLiteral("active");
    r.since = AuraDates::toMs(QDate::currentDate());
    setRelation(r);
    rpc(QStringLiteral("accept_invitation"), {}, true);
}

void CoachStore::declineInvitation()
{
    setRelation(Coaching());
    rpc(QStringLiteral("decline_invitation"), {}, true);
}

void CoachStore::leave()
{
    setRelation(Coaching());
    rpc(QStringLiteral("leave_coach"), {}, true);
}

void CoachStore::acceptRequest(const QString &coachingId)
{
    m_requests.removeIf([&](const Coaching &c) { return c.id == coachingId; });
    changed();
    rpc(QStringLiteral("respond_coach_request"),
        {{QStringLiteral("p_coaching"), coachingId}, {QStringLiteral("p_accept"), true}}, true);
}

void CoachStore::declineRequest(const QString &coachingId)
{
    m_requests.removeIf([&](const Coaching &c) { return c.id == coachingId; });
    changed();
    rpc(QStringLiteral("respond_coach_request"),
        {{QStringLiteral("p_coaching"), coachingId}, {QStringLiteral("p_accept"), false}}, false);
}

void CoachStore::setVisibility(const QString &visibility)
{
    for (Coach &c : m_coaches)
        if (c.id == userId())
            c.visibility = visibility;
    if (visibility == QLatin1String("private"))
        m_requests.clear();
    changed();
    rpc(QStringLiteral("set_visibility"), {{QStringLiteral("p_visibility"), visibility}}, false);
}
