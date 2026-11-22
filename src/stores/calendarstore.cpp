// See calendarstore.hpp.
#include "calendarstore.hpp"

#include "supabaseclient.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QLocale>

#include <algorithm>
#include <cmath>

namespace {

QDate toDate(double ms)
{
    return QDateTime::fromMSecsSinceEpoch(qint64(ms)).date();
}

double toMs(const QDate &date)
{
    return double(date.startOfDay().toMSecsSinceEpoch());
}

void sortByStart(QList<CalendarSession> &list)
{
    std::sort(list.begin(), list.end(),
              [](const CalendarSession &a, const CalendarSession &b) { return a.startMs() < b.startMs(); });
}

} // namespace

CalendarStore::CalendarStore(QObject *parent)
    : StoreBase(parent)
    , m_now(QDateTime::currentMSecsSinceEpoch())
{
    // Once a minute: slots turn "past" while the app is open
    m_clock.setInterval(60000);
    connect(&m_clock, &QTimer::timeout, this, [this] {
        m_now = QDateTime::currentMSecsSinceEpoch();
        emit nowChanged();
        changed();
    });
    m_clock.start();
    // A client's coach changes when they join or leave one
    start({QStringLiteral("coachings"), QStringLiteral("sessions"), QStringLiteral("blocked_slots"),
           QStringLiteral("working_hours")});
}

// ---- loading --------------------------------------------------------------------

void CalendarStore::load()
{
    // Own hours, own blocked slots, sessions, the client's coach; then (for a
    // client) that coach's hours and busy times
    const int generation = beginLoad(6);
    const QString me = userId();

    QUrlQuery hours;
    hours.addQueryItem(QStringLiteral("select"), QStringLiteral("weekday,start_min,end_min"));
    hours.addQueryItem(QStringLiteral("coach_id"), QStringLiteral("eq.") + me);
    m_client->select(this, QStringLiteral("working_hours"), hours,
                     [this, generation, me](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         const QJsonArray rows = reply.data.array();
                         if (!rows.isEmpty() || m_calendars.contains(me))
                             m_calendars[me].hours = WeeklyHours::fromRows(rows);
                         changed();
                     });

    QUrlQuery blocked;
    blocked.addQueryItem(QStringLiteral("select"), QStringLiteral("starts_at"));
    blocked.addQueryItem(QStringLiteral("coach_id"), QStringLiteral("eq.") + me);
    m_client->select(this, QStringLiteral("blocked_slots"), blocked,
                     [this, generation, me](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         QHash<QString, QSet<int>> daySlots;
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows) {
                             const QDateTime t = QDateTime::fromString(
                                 row.toObject().value(QStringLiteral("starts_at")).toString(), Qt::ISODateWithMs).toLocalTime();
                             daySlots[CalendarTime::dateKey(t.date())].insert(t.time().hour() * 60 + t.time().minute());
                         }
                         if (!daySlots.isEmpty() || m_calendars.contains(me))
                             m_calendars[me].blocked = daySlots;
                         changed();
                     });

    // RLS: the coach's sessions, or the client's own
    QUrlQuery sessions;
    sessions.addQueryItem(QStringLiteral("select"),
                          QStringLiteral("id,coach_id,client_id,client_name,client_email,starts_at,ends_at,"
                                         "type,mode,note,status,requested_at,cancelled_by"));
    sessions.addQueryItem(QStringLiteral("order"), QStringLiteral("starts_at.asc"));
    m_client->select(this, QStringLiteral("sessions"), sessions,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_sessions.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows)
                             m_sessions.append(CalendarSession::fromJson(row.toObject()));
                         sortByStart(m_sessions);
                         changed();
                     });

    QUrlQuery coach;
    coach.addQueryItem(QStringLiteral("select"), QStringLiteral("coach_id"));
    coach.addQueryItem(QStringLiteral("client_id"), QStringLiteral("eq.") + me);
    coach.addQueryItem(QStringLiteral("status"), QStringLiteral("in.(active,paused)"));
    m_client->select(this, QStringLiteral("coachings"), coach,
                     [this, generation](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         const QJsonArray rows = reply.data.array();
                         if (!reply.ok() || rows.isEmpty()) {
                             endLoadStep();     // no coach to load
                             endLoadStep();
                             return;
                         }
                         loadCoach(rows.first().toObject().value(QStringLiteral("coach_id")).toString(), generation);
                     });
}

// The client's coach: hours, and busy times for the weeks clients can book
void CalendarStore::loadCoach(const QString &coachId, int generation)
{
    QUrlQuery hours;
    hours.addQueryItem(QStringLiteral("select"), QStringLiteral("weekday,start_min,end_min"));
    hours.addQueryItem(QStringLiteral("coach_id"), QStringLiteral("eq.") + coachId);
    m_client->select(this, QStringLiteral("working_hours"), hours,
                     [this, generation, coachId](const SupabaseClient::Reply &reply) {
                         if (!isCurrent(generation))
                             return;
                         endLoadStep();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_calendars[coachId].hours = WeeklyHours::fromRows(reply.data.array());
                         changed();
                     });

    const QDate from = toDate(mondayOf(double(m_now)));
    const QDate to = from.addDays(7 * bookingWeeks());
    m_client->rpc(this, QStringLiteral("coach_busy"),
                  {{QStringLiteral("p_coach"), coachId},
                   {QStringLiteral("p_from"), CalendarTime::toServer(from, 0)},
                   {QStringLiteral("p_to"), CalendarTime::toServer(to, 0)}},
                  [this, generation, coachId](const SupabaseClient::Reply &reply) {
                      if (!isCurrent(generation))
                          return;
                      endLoadStep();
                      if (!reply.ok()) {
                          emit errorOccurred(errorText(reply.errorCode));
                          return;
                      }
                      QList<QPair<qint64, qint64>> busy;
                      const QJsonArray rows = reply.data.array();
                      for (const QJsonValue &row : rows) {
                          const QJsonObject o = row.toObject();
                          busy.append({QDateTime::fromString(o.value(QStringLiteral("starts_at")).toString(), Qt::ISODateWithMs).toMSecsSinceEpoch(),
                                       QDateTime::fromString(o.value(QStringLiteral("ends_at")).toString(), Qt::ISODateWithMs).toMSecsSinceEpoch()});
                      }
                      m_calendars[coachId].busy = busy;
                      changed();
                  });
}

bool CalendarStore::clearData()
{
    if (m_calendars.isEmpty() && m_sessions.isEmpty())
        return false;
    m_calendars.clear();
    m_sessions.clear();
    return true;
}

QString CalendarStore::errorText(const QString &code) const
{
    if (code == QLatin1String("slot_unavailable"))
        return tr("This time isn't free any more. Please choose another one.");
    if (code == QLatin1String("too_soon"))
        return tr("Sessions have to be booked at least %1 minutes ahead.").arg(minNoticeMinutes());
    if (code == QLatin1String("too_far"))
        return tr("Sessions can be booked up to %1 weeks ahead.").arg(bookingWeeks());
    if (code == QLatin1String("invalid_length"))
        return tr("Sessions last from 30 minutes to 3 hours, in 30-minute steps.");
    if (code == QLatin1String("too_late_to_cancel"))
        return tr("It's less than %1 hours to the session, so it can't be cancelled any more.").arg(cancelNoticeHours());
    if (code == QLatin1String("invalid_hours"))
        return tr("The working hours couldn't be saved: check that no ranges overlap.");
    if (code == QLatin1String("not_a_coach"))
        return tr("Only coaches can do this.");
    if (code == QLatin1String("not_a_client"))
        return tr("Only client accounts can book sessions.");
    if (code == QLatin1String("23505"))
        return tr("This slot was already blocked.");
    return StoreBase::errorText(code);
}

const CoachCalendar &CalendarStore::own() const
{
    static const CoachCalendar empty;
    const auto it = m_calendars.constFind(userId());
    return it == m_calendars.cend() ? empty : *it;
}

const CoachCalendar *CalendarStore::calendarOf(const QString &coachId) const
{
    const auto it = m_calendars.constFind(coachId);
    return it == m_calendars.cend() ? nullptr : &*it;
}

CalendarSession *CalendarStore::find(const QString &id)
{
    for (CalendarSession &s : m_sessions)
        if (s.id == id)
            return &s;
    return nullptr;
}

QVariantMap CalendarStore::blocked() const
{
    QVariantMap map;
    const CoachCalendar &cal = own();
    for (auto it = cal.blocked.cbegin(); it != cal.blocked.cend(); ++it) {
        if (it->isEmpty())
            continue;
        QList<int> minutes(it->cbegin(), it->cend());
        std::sort(minutes.begin(), minutes.end());
        QVariantList list;
        for (int m : minutes)
            list.append(m);
        map.insert(it.key(), list);
    }
    return map;
}

QList<CalendarSession> CalendarStore::pendingBookings() const
{
    QList<CalendarSession> list;
    const QString me = userId();
    for (const CalendarSession &s : m_sessions)
        if (s.coachId == me && s.status == QLatin1String("pending") && s.endMs() > double(m_now))
            list.append(s);
    sortByStart(list);
    return list;
}

// ---- dates and text -------------------------------------------------------------

QString CalendarStore::dateKey(double ms) const
{
    return CalendarTime::dateKey(toDate(ms));
}

double CalendarStore::startOfDay(double ms) const
{
    return toMs(toDate(ms));
}

double CalendarStore::addDays(double ms, int days) const
{
    return toMs(toDate(ms).addDays(days));
}

double CalendarStore::mondayOf(double ms) const
{
    const QDate d = toDate(ms);
    return toMs(d.addDays(1 - d.dayOfWeek()));     // dayOfWeek: Monday = 1
}

QString CalendarStore::formatMinutes(int minutes) const
{
    return QStringLiteral("%1:%2").arg(minutes / 60, 2, 10, QLatin1Char('0')).arg(minutes % 60, 2, 10, QLatin1Char('0'));
}

QString CalendarStore::durationText(int minutes) const
{
    const int h = minutes / 60;
    const int m = minutes % 60;
    if (h == 0)
        return tr("%1 min").arg(m);
    return m == 0 ? tr("%1 h").arg(h) : tr("%1 h %2 min").arg(h).arg(m);
}

QString CalendarStore::hoursText(double hours) const
{
    if (hours == 1)
        return tr("1 h");
    const bool whole = hours == std::floor(hours);
    return tr("%1 h").arg(whole ? QString::number(qint64(hours)) : QString::number(hours, 'f', 1));
}

QString CalendarStore::statusText(const QVariant &value) const
{
    const CalendarSession s = CalendarSession::fromVariant(value);
    if (s.status == QLatin1String("pending"))
        return tr("Waiting for confirmation");
    if (s.status == QLatin1String("declined"))
        return tr("Declined");
    if (s.status == QLatin1String("cancelled"))
        return s.cancelledBy == QLatin1String("coach") ? tr("Cancelled by your coach") : tr("Cancelled");
    return tr("Confirmed");
}

QString CalendarStore::statusTone(const QVariant &value) const
{
    const QString status = CalendarSession::fromVariant(value).status;
    if (status == QLatin1String("pending"))
        return QStringLiteral("accent");
    if (status == QLatin1String("declined"))
        return QStringLiteral("danger");
    if (status == QLatin1String("cancelled"))
        return QStringLiteral("neutral");
    return QStringLiteral("primary");
}

bool CalendarStore::isActive(const QVariant &session) const
{
    return CalendarSession::fromVariant(session).isActive();
}

double CalendarStore::startMs(const QVariant &session) const
{
    return CalendarSession::fromVariant(session).startMs();
}

double CalendarStore::endMs(const QVariant &session) const
{
    return CalendarSession::fromVariant(session).endMs();
}

// ---- working hours ----------------------------------------------------------------

QJSValue CalendarStore::cloneHours() const
{
    return toJs(own().hours.toVariantMap());
}

void CalendarStore::saveWeeklyHours(const QVariant &hours)
{
    const WeeklyHours clean = WeeklyHours::fromVariant(hours);
    m_calendars[userId()].hours = clean;
    changed();
    writeRpc(QStringLiteral("save_working_hours"), {{QStringLiteral("p_hours"), clean.toSaveJson()}},
             [this] { notify(QStringLiteral("working_hours")); });
}

int CalendarStore::totalWeeklyMinutes(const QVariant &hours, const QVariant &) const
{
    const WeeklyHours h = WeeklyHours::fromVariant(hours);
    int total = 0;
    for (int d = 0; d < 7; ++d)
        for (const auto &r : h.on(d))
            total += r.end - r.start;
    return total;
}

QString CalendarStore::rangeProblem(const QVariant &value) const
{
    QList<WeeklyHours::Range> ranges;
    const QVariantList list = value.toList();
    for (const QVariant &r : list) {
        const QVariantMap m = r.toMap();
        ranges.append({m.value(QStringLiteral("start")).toInt(), m.value(QStringLiteral("end")).toInt()});
    }
    std::sort(ranges.begin(), ranges.end(), [](const auto &a, const auto &b) { return a.start < b.start; });
    for (int i = 0; i < ranges.size(); ++i) {
        if (ranges[i].end <= ranges[i].start)
            return tr("A time range ends before it starts.");
        if (i > 0 && ranges[i].start < ranges[i - 1].end)
            return tr("Two time ranges overlap.");
    }
    return {};
}

// ---- the coach's own calendar -----------------------------------------------------

bool CalendarStore::isWorkingSlot(const QDate &date, int minute) const
{
    return own().hours.covers(date, minute, slotMinutes());
}

bool CalendarStore::isBlocked(double dayMs, int minute, const QVariant &) const
{
    return own().isBlocked(toDate(dayMs), minute);
}

void CalendarStore::setBlocked(double dayMs, const QVariantList &minutes, bool value)
{
    const QDate date = toDate(dayMs);
    const QString key = CalendarTime::dateKey(date);
    QSet<int> &daySlots = m_calendars[userId()].blocked[key];
    QJsonArray rows;
    QStringList instants;
    for (const QVariant &v : minutes) {
        const int m = v.toInt();
        if (value == daySlots.contains(m))
            continue;
        if (value) {
            daySlots.insert(m);
            rows.append(QJsonObject{{QStringLiteral("coach_id"), userId()},
                                    {QStringLiteral("starts_at"), CalendarTime::toServer(date, m)}});
        } else {
            daySlots.remove(m);
            instants.append(CalendarTime::toServer(date, m));
        }
    }
    if (rows.isEmpty() && instants.isEmpty())
        return;
    changed();
    if (!rows.isEmpty()) {
        write([this, rows](SupabaseClient::Callback done) { m_client->insert(this, QStringLiteral("blocked_slots"), rows, done); });
    } else {
        QUrlQuery filter;
        filter.addQueryItem(QStringLiteral("coach_id"), QStringLiteral("eq.") + userId());
        filter.addQueryItem(QStringLiteral("starts_at"), QStringLiteral("in.(%1)").arg(instants.join(QLatin1Char(','))));
        write([this, filter](SupabaseClient::Callback done) { m_client->remove(this, QStringLiteral("blocked_slots"), filter, done); });
    }
}

QList<CalendarSession> CalendarStore::coachSessionsOn(const QString &coachId, const QDate &date) const
{
    const QString key = CalendarTime::dateKey(date);
    QList<CalendarSession> list;
    for (const CalendarSession &s : m_sessions)
        if (s.coachId == coachId && s.dateKey == key && s.isActive())
            list.append(s);
    std::sort(list.begin(), list.end(), [](const auto &a, const auto &b) { return a.start < b.start; });
    return list;
}

QList<CalendarSession> CalendarStore::sessionsOn(double dayMs, const QVariant &) const
{
    return coachSessionsOn(userId(), toDate(dayMs));
}

QVariant CalendarStore::sessionAt(double dayMs, int minute, const QVariant &) const
{
    for (const CalendarSession &s : sessionsOn(dayMs))
        if (minute >= s.start && minute < s.end)
            return QVariant::fromValue(s);
    return QVariant::fromValue(nullptr);
}

bool CalendarStore::isPast(double dayMs, int minute, const QVariant &) const
{
    return CalendarTime::toMs(toDate(dayMs), minute + slotMinutes()) <= m_now;
}

QString CalendarStore::slotState(double dayMs, int minute, const QVariant &) const
{
    const QDate date = toDate(dayMs);
    const QList<CalendarSession> sessions = coachSessionsOn(userId(), date);
    if (std::any_of(sessions.cbegin(), sessions.cend(),
                    [&](const CalendarSession &s) { return minute >= s.start && minute < s.end; }))
        return QStringLiteral("booked");
    if (!isWorkingSlot(date, minute))
        return QStringLiteral("outside");
    return own().isBlocked(date, minute) ? QStringLiteral("blocked") : QStringLiteral("available");
}

bool CalendarStore::isToggleable(double dayMs, int minute, const QVariant &) const
{
    const QString state = slotState(dayMs, minute);
    return (state == QLatin1String("available") || state == QLatin1String("blocked")) && !isPast(dayMs, minute);
}

QVariantMap CalendarStore::visibleRange(double mondayMs, const QVariant &) const
{
    int from = defaultFrom();
    int to = defaultTo();
    const QDate monday = toDate(mondayMs);
    for (int i = 0; i < 7; ++i) {
        const QDate day = monday.addDays(i);
        for (const auto &r : own().hours.on(day)) {
            from = std::min(from, r.start);
            to = std::max(to, r.end);
        }
        for (const CalendarSession &s : coachSessionsOn(userId(), day)) {
            from = std::min(from, s.start);
            to = std::max(to, s.end);
        }
    }
    return {{QStringLiteral("from"), std::max(0, from / 60 * 60)},
            {QStringLiteral("to"), std::min(24 * 60, (to + 59) / 60 * 60)}};
}

QVariantMap CalendarStore::weekStats(double mondayMs, const QVariant &) const
{
    int available = 0;
    int blockedCount = 0;
    int booked = 0;
    const QDate monday = toDate(mondayMs);
    for (int i = 0; i < 7; ++i) {
        const QDate day = monday.addDays(i);
        const double dayStart = toMs(day);
        for (int m = 0; m < 24 * 60; m += slotMinutes()) {
            if (isPast(dayStart, m))
                continue;
            const QString state = slotState(dayStart, m);
            if (state == QLatin1String("available"))
                ++available;
            else if (state == QLatin1String("blocked"))
                ++blockedCount;
        }
        for (const CalendarSession &s : coachSessionsOn(userId(), day))
            if (!isPast(dayStart, s.end - slotMinutes()))
                ++booked;
    }
    return {{QStringLiteral("availableHours"), available * slotMinutes() / 60.0},
            {QStringLiteral("blockedHours"), blockedCount * slotMinutes() / 60.0},
            {QStringLiteral("sessions"), booked}};
}

// ---- sessions -----------------------------------------------------------------------

QVariant CalendarStore::sessionById(const QString &id, const QVariant &) const
{
    for (const CalendarSession &s : m_sessions)
        if (s.id == id)
            return QVariant::fromValue(s);
    return QVariant::fromValue(nullptr);
}

QList<CalendarSession> CalendarStore::clientSessions(const QString &email, const QString &name, const QVariant &) const
{
    QList<CalendarSession> list;
    for (const CalendarSession &s : m_sessions) {
        const bool mine = s.clientEmail.isEmpty() ? s.client == name
                                                  : s.clientEmail.compare(email.trimmed(), Qt::CaseInsensitive) == 0;
        if (mine)
            list.append(s);
    }
    return list;     // m_sessions is sorted by start
}

QVariant CalendarStore::nextSessionFor(const QString &email, const QString &name, const QVariant &) const
{
    for (const CalendarSession &s : clientSessions(email, name))
        if (s.isActive() && s.endMs() > double(m_now))
            return QVariant::fromValue(s);
    return QVariant::fromValue(nullptr);
}

bool CalendarStore::canClientCancel(const QVariant &value, const QVariant &) const
{
    const CalendarSession s = CalendarSession::fromVariant(value);
    return s.isActive() && s.startMs() - double(m_now) >= cancelNoticeHours() * 3600000.0;
}

void CalendarStore::setStatus(const QString &id, const QString &status, const QString &cancelledBy)
{
    CalendarSession *s = find(id);
    if (!s)
        return;
    s->status = status;
    s->cancelledBy = cancelledBy;
    changed();
}

void CalendarStore::confirmSession(const QString &id)
{
    setStatus(id, QStringLiteral("confirmed"));
    writeRpc(QStringLiteral("respond_session"), {{QStringLiteral("p_session"), id}, {QStringLiteral("p_confirm"), true}},
             [this] { notify(QStringLiteral("sessions")); });
}

void CalendarStore::declineSession(const QString &id)
{
    setStatus(id, QStringLiteral("declined"));
    writeRpc(QStringLiteral("respond_session"), {{QStringLiteral("p_session"), id}, {QStringLiteral("p_confirm"), false}});
}

void CalendarStore::cancelSession(const QString &id, const QString &by)
{
    setStatus(id, QStringLiteral("cancelled"), by.isEmpty() ? QStringLiteral("client") : by);
    writeRpc(QStringLiteral("cancel_session"), {{QStringLiteral("p_session"), id}},
             [this] { notify(QStringLiteral("sessions")); });
}

// ---- booking --------------------------------------------------------------------------

bool CalendarStore::isCoachWorkingSlot(const QString &coachId, double dayMs, int minute, const QVariant &) const
{
    const CoachCalendar *cal = calendarOf(coachId);
    return cal && cal->hours.covers(toDate(dayMs), minute, slotMinutes());
}

bool CalendarStore::isCoachSlotFree(const QString &coachId, double dayMs, int minute, const QVariant &) const
{
    const QDate date = toDate(dayMs);
    const qint64 slotStart = CalendarTime::toMs(date, minute);
    if (slotStart < m_now + qint64(minNoticeMinutes()) * 60000)
        return false;
    if (coachId == userId())
        return slotState(dayMs, minute) == QLatin1String("available");
    const CoachCalendar *cal = calendarOf(coachId);
    if (!cal || !cal->hours.covers(date, minute, slotMinutes()) || cal->isBlocked(date, minute))
        return false;
    if (cal->isBusy(slotStart, slotStart + qint64(slotMinutes()) * 60000))
        return false;
    // The user's own requests, including ones the server hasn't confirmed yet
    const QList<CalendarSession> mine = coachSessionsOn(coachId, date);
    return std::none_of(mine.cbegin(), mine.cend(),
                        [&](const CalendarSession &s) { return minute >= s.start && minute < s.end; });
}

bool CalendarStore::isRangeFree(const QString &coachId, double dayMs, int start, int end, const QVariant &) const
{
    for (int m = start; m < end; m += slotMinutes())
        if (!isCoachSlotFree(coachId, dayMs, m))
            return false;
    return end > start;
}

QList<int> CalendarStore::bookableStarts(const QString &coachId, double dayMs, int duration, const QVariant &) const
{
    QList<int> starts;
    for (int m = 0; m + duration <= 24 * 60; m += slotMinutes()) {
        bool free = true;
        for (int k = m; k < m + duration && free; k += slotMinutes())
            free = isCoachSlotFree(coachId, dayMs, k);
        if (free)
            starts.append(m);
    }
    return starts;
}

QVariantMap CalendarStore::coachVisibleRange(const QString &coachId, double mondayMs, const QVariant &) const
{
    if (coachId == userId())
        return visibleRange(mondayMs);
    const CoachCalendar *cal = calendarOf(coachId);
    int from = defaultFrom();
    int to = defaultTo();
    const QDate monday = toDate(mondayMs);
    for (int i = 0; i < 7; ++i) {
        const QDate day = monday.addDays(i);
        if (cal) {
            for (const auto &r : cal->hours.on(day)) {
                from = std::min(from, r.start);
                to = std::max(to, r.end);
            }
            for (const auto &b : cal->busy) {
                const QDateTime s = QDateTime::fromMSecsSinceEpoch(b.first);
                if (s.date() != day)
                    continue;
                const int start = s.time().hour() * 60 + s.time().minute();
                from = std::min(from, start);
                to = std::max(to, start + int((b.second - b.first) / 60000));
            }
        }
        for (const CalendarSession &s : coachSessionsOn(coachId, day)) {
            from = std::min(from, s.start);
            to = std::max(to, s.end);
        }
    }
    return {{QStringLiteral("from"), from / 60 * 60}, {QStringLiteral("to"), std::min(24 * 60, (to + 59) / 60 * 60)}};
}

QString CalendarStore::requestSession(const QString &coachId, double dayMs, int start, int end, const QString &type,
                                      const QString &mode, const QString &note, const QString &clientName,
                                      const QString &clientEmail)
{
    const QDate date = toDate(dayMs);
    CalendarSession s;
    s.id = newId();
    s.coachId = coachId;
    s.clientId = userId();
    s.dateKey = CalendarTime::dateKey(date);
    s.start = start;
    s.end = end;
    s.client = clientName;
    s.clientEmail = clientEmail.trimmed().toLower();
    s.type = type;
    s.mode = mode;
    s.note = note.trimmed();
    s.status = QStringLiteral("pending");
    s.requestedAt = double(QDateTime::currentMSecsSinceEpoch());
    m_sessions.append(s);
    sortByStart(m_sessions);
    changed();
    writeRpc(QStringLiteral("request_session"),
             {{QStringLiteral("p_coach"), coachId},
              {QStringLiteral("p_starts"), CalendarTime::toServer(date, start)},
              {QStringLiteral("p_ends"), CalendarTime::toServer(date, end)},
              {QStringLiteral("p_type"), type},
              {QStringLiteral("p_mode"), mode},
              {QStringLiteral("p_note"), s.note},
              {QStringLiteral("p_id"), s.id}});
    return s.id;
}
