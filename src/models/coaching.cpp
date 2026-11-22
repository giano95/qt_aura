// See coaching.hpp.
#include "coaching.hpp"

#include <QDateTime>
#include <QJsonArray>

#include <algorithm>

namespace {

QString str(const QJsonObject &o, const char *key)
{
    return o.value(QLatin1String(key)).toString();
}

QString str(const QVariantMap &m, const char *key)
{
    return m.value(QLatin1String(key)).toString();
}

QStringList strings(const QJsonValue &value)
{
    QStringList list;
    const QJsonArray array = value.toArray();
    for (const QJsonValue &v : array)
        list.append(v.toString());
    return list;
}

} // namespace

// ---- dates ----------------------------------------------------------------------

double AuraDates::toMs(const QDate &date)
{
    return date.isValid() ? double(date.startOfDay().toMSecsSinceEpoch()) : 0;
}

QDate AuraDates::toDate(double ms)
{
    return QDateTime::fromMSecsSinceEpoch(qint64(ms)).date();
}

double AuraDates::fromIsoDate(const QString &text)
{
    return toMs(QDate::fromString(text, Qt::ISODate));
}

double AuraDates::fromIsoDateTime(const QString &text)
{
    const QDateTime t = QDateTime::fromString(text, Qt::ISODateWithMs);
    return t.isValid() ? double(t.toMSecsSinceEpoch()) : 0;
}

// ---- Assignment -----------------------------------------------------------------

Assignment Assignment::fromJson(const QJsonObject &row)
{
    Assignment a;
    a.id = str(row, "id");
    a.programId = str(row, "program_id");
    a.programName = str(row, "program_name");
    a.weeks = row.value(QStringLiteral("weeks")).toInt();
    a.start = AuraDates::fromIsoDate(str(row, "start_date"));
    a.note = str(row, "note");
    a.endedAt = AuraDates::fromIsoDate(str(row, "ended_on"));
    a.endReason = str(row, "end_reason");
    return a;
}

Assignment Assignment::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<Assignment>())
        return value.value<Assignment>();
    const QVariantMap map = value.toMap();
    Assignment a;
    a.id = str(map, "id");
    a.programId = str(map, "programId");
    a.programName = str(map, "programName");
    a.weeks = map.value(QStringLiteral("weeks")).toInt();
    a.start = map.value(QStringLiteral("start")).toDouble();
    a.note = str(map, "note");
    a.endedAt = map.value(QStringLiteral("endedAt")).toDouble();
    a.endReason = str(map, "endReason");
    return a;
}

// ---- ProgramStatus --------------------------------------------------------------

QVariantMap ProgramStatus::toVariantMap() const
{
    return {{QStringLiteral("kind"), kind},
            {QStringLiteral("assignment"), assignment ? QVariant::fromValue(*assignment)
                                                      : QVariant::fromValue(nullptr)},
            {QStringLiteral("daysUntil"), daysUntil},
            {QStringLiteral("daysAgo"), daysAgo},
            {QStringLiteral("week"), week},
            {QStringLiteral("daysLeft"), daysLeft},
            {QStringLiteral("progress"), progress},
            {QStringLiteral("lastDay"), AuraDates::toMs(lastDay)}};
}

ProgramStatus ProgramStatus::fromVariant(const QVariant &value)
{
    const QVariantMap map = value.toMap();
    ProgramStatus s;
    s.kind = map.value(QStringLiteral("kind"), QStringLiteral("none")).toString();
    const QVariant a = map.value(QStringLiteral("assignment"));
    if (a.isValid() && !a.isNull() && a.metaType() != QMetaType::fromType<std::nullptr_t>())
        s.assignment = Assignment::fromVariant(a);
    s.daysUntil = map.value(QStringLiteral("daysUntil")).toInt();
    s.daysAgo = map.value(QStringLiteral("daysAgo")).toInt();
    s.week = map.value(QStringLiteral("week")).toInt();
    s.daysLeft = map.value(QStringLiteral("daysLeft")).toInt();
    s.progress = map.value(QStringLiteral("progress")).toDouble();
    s.lastDay = AuraDates::toDate(map.value(QStringLiteral("lastDay")).toDouble());
    return s;
}

// ---- Client ---------------------------------------------------------------------

int Client::currentIndex() const
{
    for (int i = int(assignments.size()) - 1; i >= 0; --i)
        if (assignments.at(i).endedAt == 0)
            return i;
    return -1;
}

std::optional<Assignment> Client::currentAssignment() const
{
    const int i = currentIndex();
    return i < 0 ? std::nullopt : std::optional<Assignment>(assignments.at(i));
}

QList<Assignment> Client::pastAssignments() const
{
    QList<Assignment> past;
    for (const Assignment &a : assignments)
        if (a.endedAt != 0)
            past.append(a);
    std::sort(past.begin(), past.end(), [](const Assignment &a, const Assignment &b) { return a.start > b.start; });
    return past;
}

ProgramStatus Client::programStatus(const QDate &today) const
{
    ProgramStatus s;
    s.assignment = currentAssignment();
    if (!s.assignment)
        return s;
    const QDate start = s.assignment->startDate();
    s.lastDay = s.assignment->lastDate();
    if (today < start) {
        s.kind = QStringLiteral("scheduled");
        s.daysUntil = int(today.daysTo(start));
    } else if (today > s.lastDay) {
        s.kind = QStringLiteral("expired");
        s.daysAgo = int(s.lastDay.daysTo(today));
    } else {
        s.daysLeft = int(today.daysTo(s.lastDay));
        s.kind = s.daysLeft < 7 ? QStringLiteral("endingSoon") : QStringLiteral("active");
        const qint64 elapsed = start.daysTo(today);
        s.week = int(elapsed / 7) + 1;
        s.progress = double(elapsed + 1) / (s.assignment->weeks * 7);
    }
    return s;
}

void Client::assign(const Assignment &assignment, const QDate &today)
{
    const int i = currentIndex();
    if (i >= 0) {
        Assignment &current = assignments[i];
        const QDate last = current.lastDate();
        if (today > last) {
            current.endedAt = AuraDates::toMs(last);
            current.endReason = QStringLiteral("completed");
        } else if (today < current.startDate()) {
            // Never started: drop it instead of keeping it in the history
            assignments.removeAt(i);
        } else {
            current.endedAt = AuraDates::toMs(today);
            current.endReason = QStringLiteral("replaced");
        }
    }
    assignments.append(assignment);
    if (status == QLatin1String("paused"))
        status = QStringLiteral("active");
}

bool Client::endProgram(const QDate &today)
{
    const int i = currentIndex();
    if (i < 0)
        return false;
    Assignment &current = assignments[i];
    const QDate last = current.lastDate();
    if (today < current.startDate()) {
        assignments.removeAt(i);
    } else if (today > last) {
        current.endedAt = AuraDates::toMs(last);
        current.endReason = QStringLiteral("completed");
    } else {
        current.endedAt = AuraDates::toMs(today);
        current.endReason = QStringLiteral("ended");
    }
    return true;
}

bool Client::extend(int weeks)
{
    const int i = currentIndex();
    if (i < 0)
        return false;
    assignments[i].weeks += weeks;
    return true;
}

bool Client::matchesFilter(const QString &filter, const QDate &today) const
{
    const QString kind = programStatus(today).kind;
    if (filter == QLatin1String("expired"))
        return kind == QLatin1String("expired");
    if (filter == QLatin1String("endingSoon"))
        return kind == QLatin1String("endingSoon");
    if (filter == QLatin1String("none"))
        return kind == QLatin1String("none") && status != QLatin1String("invited");
    if (filter == QLatin1String("invited"))
        return status == QLatin1String("invited");
    if (filter == QLatin1String("paused"))
        return status == QLatin1String("paused");
    return true;
}

Client Client::fromJson(const QJsonObject &row)
{
    Client c;
    c.id = str(row, "id");
    c.userId = str(row, "client_id");
    c.coachId = str(row, "coach_id");
    c.name = str(row, "name");
    c.email = str(row, "email");
    c.phone = str(row, "phone");
    c.goal = str(row, "goal");
    c.status = str(row, "status");
    c.since = AuraDates::fromIsoDate(str(row, "since"));
    c.lastCheckIn = AuraDates::fromIsoDate(str(row, "last_check_in"));
    QList<QJsonObject> rows;
    const QJsonArray array = row.value(QStringLiteral("assignments")).toArray();
    for (const QJsonValue &a : array)
        rows.append(a.toObject());
    // Oldest first, so the current one is the last without an end
    std::stable_sort(rows.begin(), rows.end(), [](const QJsonObject &a, const QJsonObject &b) {
        return a.value(QStringLiteral("created_at")).toString() < b.value(QStringLiteral("created_at")).toString();
    });
    for (const QJsonObject &a : rows)
        c.assignments.append(Assignment::fromJson(a));
    return c;
}

Client Client::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<Client>())
        return value.value<Client>();
    const QVariantMap map = value.toMap();
    Client c;
    c.id = str(map, "id");
    c.userId = str(map, "userId");
    c.coachId = str(map, "coachId");
    c.name = str(map, "name");
    c.email = str(map, "email");
    c.phone = str(map, "phone");
    c.goal = str(map, "goal");
    c.status = str(map, "status");
    c.since = map.value(QStringLiteral("since")).toDouble();
    c.lastCheckIn = map.value(QStringLiteral("lastCheckIn")).toDouble();
    c.nextSession = map.value(QStringLiteral("nextSession")).toDouble();
    const QVariantList list = map.value(QStringLiteral("assignments")).toList();
    for (const QVariant &a : list)
        c.assignments.append(Assignment::fromVariant(a));
    return c;
}

// ---- Coach ----------------------------------------------------------------------

bool Coach::matches(const QString &query) const
{
    const QString q = query.trimmed();
    if (q.isEmpty())
        return true;
    if (name.contains(q, Qt::CaseInsensitive) || title.contains(q, Qt::CaseInsensitive)
        || city.contains(q, Qt::CaseInsensitive))
        return true;
    return std::any_of(specialties.cbegin(), specialties.cend(),
                       [&](const QString &s) { return s.contains(q, Qt::CaseInsensitive); });
}

Coach Coach::fromJson(const QJsonObject &row)
{
    Coach c;
    c.id = str(row, "id");
    c.name = str(row, "name");
    c.email = str(row, "email");
    c.phone = str(row, "phone");
    const QJsonObject p = row.value(QStringLiteral("coach_profiles")).toObject();
    c.title = str(p, "title");
    c.city = str(p, "city");
    c.online = p.value(QStringLiteral("online")).toBool();
    c.inPerson = p.value(QStringLiteral("in_person")).toBool();
    c.studio = str(p, "studio");
    c.specialties = strings(p.value(QStringLiteral("specialties")));
    c.bio = str(p, "bio");
    c.years = p.value(QStringLiteral("years")).toInt();
    c.certifications = strings(p.value(QStringLiteral("certifications")));
    c.languages = strings(p.value(QStringLiteral("languages")));
    c.priceFrom = p.value(QStringLiteral("price_from")).toInt();
    c.accepting = p.value(QStringLiteral("accepting")).toBool();
    c.visibility = str(p, "visibility");

    // Every weekday present, ranges sorted by start
    QMap<int, QList<QPair<int, int>>> days;
    const QJsonArray hours = row.value(QStringLiteral("working_hours")).toArray();
    for (const QJsonValue &h : hours) {
        const QJsonObject o = h.toObject();
        days[o.value(QStringLiteral("weekday")).toInt()].append(
            {o.value(QStringLiteral("start_min")).toInt(), o.value(QStringLiteral("end_min")).toInt()});
    }
    for (int d = 0; d < 7; ++d) {
        QList<QPair<int, int>> ranges = days.value(d);
        std::sort(ranges.begin(), ranges.end());
        QVariantList list;
        for (const auto &r : ranges)
            list.append(QVariantMap{{QStringLiteral("start"), r.first}, {QStringLiteral("end"), r.second}});
        c.weeklyHours.insert(QString::number(d), list);
    }
    return c;
}

Coach Coach::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<Coach>())
        return value.value<Coach>();
    const QVariantMap map = value.toMap();
    Coach c;
    c.id = str(map, "id");
    c.name = str(map, "name");
    c.online = map.value(QStringLiteral("online")).toBool();
    c.inPerson = map.value(QStringLiteral("inPerson")).toBool();
    c.weeklyHours = map.value(QStringLiteral("weeklyHours")).toMap();
    return c;
}

// ---- Coaching -------------------------------------------------------------------

Coaching Coaching::fromJson(const QJsonObject &row)
{
    Coaching c;
    c.id = str(row, "id");
    c.coachId = str(row, "coach_id");
    c.email = str(row, "email");
    c.name = str(row, "name");
    c.goal = str(row, "goal");
    c.message = str(row, "message");
    const QString status = str(row, "status");
    if (status == QLatin1String("requested"))
        c.status = QStringLiteral("pending");
    else if (status == QLatin1String("paused"))
        c.status = QStringLiteral("active");
    else
        c.status = status;
    c.since = (c.status == QLatin1String("pending") || c.status == QLatin1String("declined"))
                  ? AuraDates::fromIsoDateTime(str(row, "requested_at"))
                  : AuraDates::fromIsoDate(str(row, "since"));
    return c;
}
