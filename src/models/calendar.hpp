// Value types and rules for the calendar: sessions (bookings), weekly working
// hours and the 30-minute slot logic shared by the coach's and the client's
// calendars.
//
// Times are local: a session has a day (`dateKey`, "yyyy-MM-dd") and start/end
// in minutes from that day's midnight, like the screens draw them.
#pragma once

#include <QDate>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QSet>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

// A session or booking request
struct CalendarSession
{
    Q_GADGET
    QML_VALUE_TYPE(calendarSession)

    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString coachId MEMBER coachId)
    Q_PROPERTY(QString clientId MEMBER clientId)
    Q_PROPERTY(QString dateKey MEMBER dateKey)
    Q_PROPERTY(int start MEMBER start)
    Q_PROPERTY(int end MEMBER end)
    // Client's name and email
    Q_PROPERTY(QString client MEMBER client)
    Q_PROPERTY(QString clientEmail MEMBER clientEmail)
    Q_PROPERTY(QString type MEMBER type)
    Q_PROPERTY(QString mode MEMBER mode)
    Q_PROPERTY(QString note MEMBER note)
    // "confirmed" | "pending" | "declined" | "cancelled"
    Q_PROPERTY(QString status MEMBER status)
    Q_PROPERTY(double requestedAt MEMBER requestedAt)
    // "" | "client" | "coach"
    Q_PROPERTY(QString cancelledBy MEMBER cancelledBy)

public:
    QString id;
    QString coachId;
    QString clientId;
    QString dateKey;
    int start = 0;
    int end = 0;
    QString client;
    QString clientEmail;
    QString type;
    QString mode;
    QString note;
    QString status;
    double requestedAt = 0;
    QString cancelledBy;

    // Confirmed and pending sessions take up time
    bool isActive() const;
    QDate date() const;
    double startMs() const;
    double endMs() const;

    static CalendarSession fromJson(const QJsonObject &row);
    static CalendarSession fromVariant(const QVariant &value);

    bool operator==(const CalendarSession &) const = default;
};

namespace CalendarTime {
// "yyyy-MM-dd" of a local date
QString dateKey(const QDate &date);
// Local date + minutes from its midnight as an instant (ms)
qint64 toMs(const QDate &date, int minutes);
// Local midnight of the day containing `ms`
qint64 startOfDay(qint64 ms);
// UTC ISO timestamp for the server ("2026-11-25T11:00:00Z")
QString toServer(const QDate &date, int minutes);
}

// Weekly working hours: per weekday (0 = Sunday ... 6 = Saturday) sorted,
// non-overlapping ranges in minutes from midnight
class WeeklyHours
{
public:
    struct Range
    {
        int start = 0;
        int end = 0;
        bool operator==(const Range &) const = default;
    };

    QList<Range> on(int weekday) const { return m_days.value(weekday); }
    QList<Range> on(const QDate &date) const { return on(date.dayOfWeek() % 7); }
    // The whole 30-minute slot starting at `minute` is inside working hours
    bool covers(const QDate &date, int minute, int slotMinutes) const;
    bool isEmpty() const;

    void add(int weekday, int start, int end);

    // { "<weekday>": [ { start, end } ] } with all seven days
    QVariantMap toVariantMap() const;
    static WeeklyHours fromVariant(const QVariant &value);
    // Rows of working_hours (weekday, start_min, end_min)
    static WeeklyHours fromRows(const QJsonArray &rows);
    // Body for save_working_hours: [ { weekday, start, end } ]
    QJsonArray toSaveJson() const;

    bool operator==(const WeeklyHours &) const = default;

private:
    QHash<int, QList<Range>> m_days;
};

// What a calendar knows about one coach: their hours, and the times that
// aren't free. A coach's own calendar has the blocked slots and sessions in
// detail; a client only gets busy intervals for their coach (coach_busy()).
struct CoachCalendar
{
    WeeklyHours hours;
    // dateKey -> start minutes of blocked slots (own calendar only)
    QHash<QString, QSet<int>> blocked;
    // Busy instants [start, end) in ms (client's view of their coach)
    QList<QPair<qint64, qint64>> busy;

    bool isBlocked(const QDate &date, int minute) const;
    bool isBusy(qint64 fromMs, qint64 toMs) const;
};
