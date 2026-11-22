// See calendar.hpp.
#include "calendar.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QTimeZone>

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

QDateTime parseInstant(const QString &text)
{
    return QDateTime::fromString(text, Qt::ISODateWithMs).toLocalTime();
}

} // namespace

// ---- time helpers ---------------------------------------------------------------

QString CalendarTime::dateKey(const QDate &date)
{
    return date.toString(QStringLiteral("yyyy-MM-dd"));
}

qint64 CalendarTime::toMs(const QDate &date, int minutes)
{
    return date.startOfDay().toMSecsSinceEpoch() + qint64(minutes) * 60000;
}

qint64 CalendarTime::startOfDay(qint64 ms)
{
    return QDateTime::fromMSecsSinceEpoch(ms).date().startOfDay().toMSecsSinceEpoch();
}

QString CalendarTime::toServer(const QDate &date, int minutes)
{
    return QDateTime::fromMSecsSinceEpoch(toMs(date, minutes), QTimeZone::UTC).toString(Qt::ISODate);
}

// ---- CalendarSession ------------------------------------------------------------

bool CalendarSession::isActive() const
{
    return status == QLatin1String("confirmed") || status == QLatin1String("pending");
}

QDate CalendarSession::date() const
{
    return QDate::fromString(dateKey, QStringLiteral("yyyy-MM-dd"));
}

double CalendarSession::startMs() const
{
    return double(CalendarTime::toMs(date(), start));
}

double CalendarSession::endMs() const
{
    return startMs() + double(end - start) * 60000;
}

CalendarSession CalendarSession::fromJson(const QJsonObject &row)
{
    CalendarSession s;
    s.id = str(row, "id");
    s.coachId = str(row, "coach_id");
    s.clientId = str(row, "client_id");
    const QDateTime starts = parseInstant(str(row, "starts_at"));
    const QDateTime ends = parseInstant(str(row, "ends_at"));
    s.dateKey = CalendarTime::dateKey(starts.date());
    s.start = starts.time().hour() * 60 + starts.time().minute();
    s.end = s.start + int(starts.secsTo(ends) / 60);
    s.client = str(row, "client_name");
    s.clientEmail = str(row, "client_email");
    s.type = str(row, "type");
    s.mode = str(row, "mode");
    s.note = str(row, "note");
    s.status = str(row, "status");
    const QDateTime requested = parseInstant(str(row, "requested_at"));
    s.requestedAt = requested.isValid() ? double(requested.toMSecsSinceEpoch()) : 0;
    s.cancelledBy = str(row, "cancelled_by");
    return s;
}

CalendarSession CalendarSession::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<CalendarSession>())
        return value.value<CalendarSession>();
    const QVariantMap map = value.toMap();
    CalendarSession s;
    s.id = str(map, "id");
    s.coachId = str(map, "coachId");
    s.clientId = str(map, "clientId");
    s.dateKey = str(map, "dateKey");
    s.start = map.value(QStringLiteral("start")).toInt();
    s.end = map.value(QStringLiteral("end")).toInt();
    s.client = str(map, "client");
    s.clientEmail = str(map, "clientEmail");
    s.type = str(map, "type");
    s.mode = str(map, "mode");
    s.note = str(map, "note");
    s.status = str(map, "status");
    s.requestedAt = map.value(QStringLiteral("requestedAt")).toDouble();
    s.cancelledBy = str(map, "cancelledBy");
    return s;
}

// ---- WeeklyHours ----------------------------------------------------------------

bool WeeklyHours::covers(const QDate &date, int minute, int slotMinutes) const
{
    const QList<Range> ranges = on(date);
    return std::any_of(ranges.cbegin(), ranges.cend(),
                       [&](const Range &r) { return minute >= r.start && minute + slotMinutes <= r.end; });
}

bool WeeklyHours::isEmpty() const
{
    return std::all_of(m_days.cbegin(), m_days.cend(), [](const QList<Range> &l) { return l.isEmpty(); });
}

void WeeklyHours::add(int weekday, int start, int end)
{
    QList<Range> &ranges = m_days[weekday];
    ranges.append({start, end});
    std::sort(ranges.begin(), ranges.end(), [](const Range &a, const Range &b) { return a.start < b.start; });
}

QVariantMap WeeklyHours::toVariantMap() const
{
    QVariantMap map;
    for (int d = 0; d < 7; ++d) {
        QVariantList list;
        for (const Range &r : on(d))
            list.append(QVariantMap{{QStringLiteral("start"), r.start}, {QStringLiteral("end"), r.end}});
        map.insert(QString::number(d), list);
    }
    return map;
}

WeeklyHours WeeklyHours::fromVariant(const QVariant &value)
{
    WeeklyHours hours;
    const QVariantMap map = value.toMap();
    for (int d = 0; d < 7; ++d) {
        const QVariantList list = map.value(QString::number(d)).toList();
        for (const QVariant &r : list) {
            const QVariantMap range = r.toMap();
            hours.add(d, range.value(QStringLiteral("start")).toInt(), range.value(QStringLiteral("end")).toInt());
        }
    }
    return hours;
}

WeeklyHours WeeklyHours::fromRows(const QJsonArray &rows)
{
    WeeklyHours hours;
    for (const QJsonValue &row : rows) {
        const QJsonObject o = row.toObject();
        hours.add(o.value(QStringLiteral("weekday")).toInt(), o.value(QStringLiteral("start_min")).toInt(),
                  o.value(QStringLiteral("end_min")).toInt());
    }
    return hours;
}

QJsonArray WeeklyHours::toSaveJson() const
{
    QJsonArray rows;
    for (int d = 0; d < 7; ++d)
        for (const Range &r : on(d))
            rows.append(QJsonObject{{QStringLiteral("weekday"), d},
                                    {QStringLiteral("start"), r.start},
                                    {QStringLiteral("end"), r.end}});
    return rows;
}

// ---- CoachCalendar --------------------------------------------------------------

bool CoachCalendar::isBlocked(const QDate &date, int minute) const
{
    const auto it = blocked.constFind(CalendarTime::dateKey(date));
    return it != blocked.cend() && it->contains(minute);
}

bool CoachCalendar::isBusy(qint64 fromMs, qint64 toMs) const
{
    return std::any_of(busy.cbegin(), busy.cend(),
                       [&](const QPair<qint64, qint64> &b) { return b.first < toMs && fromMs < b.second; });
}
