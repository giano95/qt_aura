// Working hours, blocked slots and sessions (QML singleton `CalendarStore`),
// from the `working_hours`, `blocked_slots` and `sessions` tables.
//
// A coach gets their own calendar: hours, blocked slots and every session.
// A client gets their own sessions, plus their coach's hours and busy times
// (coach_busy(): when the coach isn't free, without who or why) for the
// booking calendar. Functions that take a `coachId` work for either.
//
// Everything works in 30-minute slots. A slot is free when it's inside the
// working hours of its weekday, not blocked, not taken by a confirmed or
// pending session, and far enough ahead (minNoticeMinutes). Every booking is
// pending until the coach confirms or declines it.
//
// Bindings that call a function reading store data or the time pass
// `revision` last (see StoreBase); it also changes once a minute, with `now`.
#pragma once

#include "calendar.hpp"
#include "storebase.hpp"

#include <QTimer>
#include <QtQml/qqmlregistration.h>

class CalendarStore : public StoreBase
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int slotMinutes READ slotMinutes CONSTANT FINAL)
    Q_PROPERTY(int dayMs READ dayMs CONSTANT FINAL)
    // Default length of a new booking
    Q_PROPERTY(int sessionMinutes READ sessionMinutes CONSTANT FINAL)
    Q_PROPERTY(int maxSessionMinutes READ maxSessionMinutes CONSTANT FINAL)
    // Clients can cancel up to this long before the start
    Q_PROPERTY(int cancelNoticeHours READ cancelNoticeHours CONSTANT FINAL)
    // Bookings start at least this far in the future
    Q_PROPERTY(int minNoticeMinutes READ minNoticeMinutes CONSTANT FINAL)
    // Clients can book this many weeks ahead (including the current one)
    Q_PROPERTY(int bookingWeeks READ bookingWeeks CONSTANT FINAL)
    // Hours the week grid always shows (07:00 to 21:00)
    Q_PROPERTY(int defaultFrom READ defaultFrom CONSTANT FINAL)
    Q_PROPERTY(int defaultTo READ defaultTo CONSTANT FINAL)

    // The current time (ms), updated once a minute
    Q_PROPERTY(double now READ now NOTIFY nowChanged FINAL)
    // The logged-in coach's hours: { "<weekday>": [ { start, end } ] }, 0 = Sunday
    Q_PROPERTY(QVariantMap weeklyHours READ weeklyHours NOTIFY revisionChanged FINAL)
    // The logged-in coach's blocked slots: { "yyyy-MM-dd": [ minute, ... ] }
    Q_PROPERTY(QVariantMap blocked READ blocked NOTIFY revisionChanged FINAL)
    // The user's sessions (any status), oldest first
    Q_PROPERTY(QList<CalendarSession> sessions READ sessions NOTIFY revisionChanged FINAL)
    // Bookings waiting for the logged-in coach, soonest first
    Q_PROPERTY(QList<CalendarSession> pendingBookings READ pendingBookings NOTIFY revisionChanged FINAL)

public:
    explicit CalendarStore(QObject *parent = nullptr);

    int slotMinutes() const { return 30; }
    int dayMs() const { return 86400000; }
    int sessionMinutes() const { return 60; }
    int maxSessionMinutes() const { return 180; }
    int cancelNoticeHours() const { return 24; }
    int minNoticeMinutes() const { return 60; }
    int bookingWeeks() const { return 4; }
    int defaultFrom() const { return 7 * 60; }
    int defaultTo() const { return 21 * 60; }

    double now() const { return double(m_now); }
    QVariantMap weeklyHours() const { return own().hours.toVariantMap(); }
    QVariantMap blocked() const;
    QList<CalendarSession> sessions() const { return m_sessions; }
    QList<CalendarSession> pendingBookings() const;

    // ---- dates and text (no store data) -------------------------------------------
    Q_INVOKABLE QString dateKey(double ms) const;
    Q_INVOKABLE double startOfDay(double ms) const;
    Q_INVOKABLE double addDays(double ms, int days) const;
    // Monday (midnight) of the week containing `ms`
    Q_INVOKABLE double mondayOf(double ms) const;
    // "09:30"
    Q_INVOKABLE QString formatMinutes(int minutes) const;
    // "30 min", "1 h", "1 h 30 min"
    Q_INVOKABLE QString durationText(int minutes) const;
    // "1 h", "12 h", "7.5 h"
    Q_INVOKABLE QString hoursText(double hours) const;
    Q_INVOKABLE QString statusText(const QVariant &session) const;
    Q_INVOKABLE QString statusTone(const QVariant &session) const;
    Q_INVOKABLE bool isActive(const QVariant &session) const;
    Q_INVOKABLE double startMs(const QVariant &session) const;
    Q_INVOKABLE double endMs(const QVariant &session) const;

    // ---- working hours (coach) ------------------------------------------------------
    // A copy for the editor (a JS object it changes in place)
    Q_INVOKABLE QJSValue cloneHours() const;
    Q_INVOKABLE void saveWeeklyHours(const QVariant &hours);
    Q_INVOKABLE int totalWeeklyMinutes(const QVariant &hours, const QVariant &revision = {}) const;
    // Problems in a day's ranges, or "" if fine
    Q_INVOKABLE QString rangeProblem(const QVariant &ranges) const;

    // ---- the coach's own calendar (pass `revision` last from bindings) -------------
    Q_INVOKABLE bool isBlocked(double dayMs, int minute, const QVariant &revision = {}) const;
    // Blocks or frees several slots of one day
    Q_INVOKABLE void setBlocked(double dayMs, const QVariantList &minutes, bool value);
    // Confirmed and pending sessions on a day, by start
    Q_INVOKABLE QList<CalendarSession> sessionsOn(double dayMs, const QVariant &revision = {}) const;
    // The session covering a slot, or null
    Q_INVOKABLE QVariant sessionAt(double dayMs, int minute, const QVariant &revision = {}) const;
    Q_INVOKABLE bool isPast(double dayMs, int minute, const QVariant &revision = {}) const;
    // "booked" | "outside" | "blocked" | "available"
    Q_INVOKABLE QString slotState(double dayMs, int minute, const QVariant &revision = {}) const;
    // A slot the coach can block or free right now
    Q_INVOKABLE bool isToggleable(double dayMs, int minute, const QVariant &revision = {}) const;
    // { from, to } minutes the week grid shows: at least defaultFrom–defaultTo,
    // extended to whole hours for hours or sessions outside that
    Q_INVOKABLE QVariantMap visibleRange(double mondayMs, const QVariant &revision = {}) const;
    // { availableHours, blockedHours, sessions } for slots that haven't passed
    Q_INVOKABLE QVariantMap weekStats(double mondayMs, const QVariant &revision = {}) const;

    // ---- sessions -------------------------------------------------------------------
    // The session, or null
    Q_INVOKABLE QVariant sessionById(const QString &id, const QVariant &revision = {}) const;
    // A client's sessions (any status), oldest first. Sessions without an email
    // are matched by name.
    Q_INVOKABLE QList<CalendarSession> clientSessions(const QString &email, const QString &name,
                                                      const QVariant &revision = {}) const;
    // The client's next confirmed or pending session, or null
    Q_INVOKABLE QVariant nextSessionFor(const QString &email, const QString &name,
                                        const QVariant &revision = {}) const;
    // A client can cancel a confirmed or pending session up to 24 h before it
    Q_INVOKABLE bool canClientCancel(const QVariant &session, const QVariant &revision = {}) const;
    Q_INVOKABLE void confirmSession(const QString &id);
    Q_INVOKABLE void declineSession(const QString &id);
    // by: "client" | "coach"
    Q_INVOKABLE void cancelSession(const QString &id, const QString &by);

    // ---- booking (any coach the user can see) ----------------------------------------
    // Inside the coach's working hours (free or not)
    Q_INVOKABLE bool isCoachWorkingSlot(const QString &coachId, double dayMs, int minute,
                                        const QVariant &revision = {}) const;
    // Can a session with the coach use this slot?
    Q_INVOKABLE bool isCoachSlotFree(const QString &coachId, double dayMs, int minute,
                                     const QVariant &revision = {}) const;
    // Every slot from start to end (exclusive) is free
    Q_INVOKABLE bool isRangeFree(const QString &coachId, double dayMs, int start, int end,
                                 const QVariant &revision = {}) const;
    // Start times where a session of `duration` minutes fits in free slots
    Q_INVOKABLE QList<int> bookableStarts(const QString &coachId, double dayMs, int duration,
                                          const QVariant &revision = {}) const;
    // Grid hours for a coach's week, like visibleRange
    Q_INVOKABLE QVariantMap coachVisibleRange(const QString &coachId, double mondayMs,
                                              const QVariant &revision = {}) const;
    // Sends a booking request (pending until the coach answers); returns its id
    Q_INVOKABLE QString requestSession(const QString &coachId, double dayMs, int start, int end,
                                       const QString &type, const QString &mode, const QString &note,
                                       const QString &clientName, const QString &clientEmail);

signals:
    void nowChanged();

protected:
    void load() override;
    bool clearData() override;
    QString errorText(const QString &code) const override;

private:
    const CoachCalendar &own() const;
    const CoachCalendar *calendarOf(const QString &coachId) const;
    CalendarSession *find(const QString &id);
    QList<CalendarSession> coachSessionsOn(const QString &coachId, const QDate &date) const;
    bool isWorkingSlot(const QDate &date, int minute) const;
    void loadCoach(const QString &coachId, int generation);
    void setStatus(const QString &id, const QString &status, const QString &cancelledBy = {});

    qint64 m_now;
    QTimer m_clock;
    // By coach id: the coach's own calendar, or the client's coach
    QHash<QString, CoachCalendar> m_calendars;
    QList<CalendarSession> m_sessions;
};
