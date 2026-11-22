// Value types for coaches, their clients and the programs assigned to them
// (tables coach_profiles, coachings, assignments). QML reads them like plain
// objects: client.name, assignment.programName, coach.weeklyHours, ...
//
// Dates are milliseconds since the epoch, like JavaScript's Date.getTime():
// a date column becomes local midnight of that day; "none" is 0.
#pragma once

#include <QDate>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QStringList>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

#include <optional>

namespace AuraDates {
// Local midnight of `date` in ms; 0 for an invalid date
double toMs(const QDate &date);
// Local date of a ms timestamp
QDate toDate(double ms);
// ISO date ("2026-11-22") or timestamp from the server, as ms; 0 if empty
double fromIsoDate(const QString &text);
double fromIsoDateTime(const QString &text);
}

// A program given to a client. Name and length are copied when it's assigned.
struct Assignment
{
    Q_GADGET
    QML_VALUE_TYPE(assignment)

    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString programId MEMBER programId)
    Q_PROPERTY(QString programName MEMBER programName)
    Q_PROPERTY(int weeks MEMBER weeks)
    Q_PROPERTY(double start MEMBER start)
    Q_PROPERTY(QString note MEMBER note)
    Q_PROPERTY(double endedAt MEMBER endedAt)
    // "" | "completed" | "replaced" | "ended"
    Q_PROPERTY(QString endReason MEMBER endReason)

public:
    QString id;
    QString programId;      // "" if the program was deleted since
    QString programName;
    int weeks = 0;
    double start = 0;       // first day
    QString note;
    double endedAt = 0;     // 0 while current
    QString endReason;

    QDate startDate() const { return AuraDates::toDate(start); }
    // Last day (inclusive)
    QDate lastDate() const { return startDate().addDays(qint64(weeks) * 7 - 1); }

    static Assignment fromJson(const QJsonObject &row);
    // An Assignment, or a JS object / map with at least { start, weeks }
    static Assignment fromVariant(const QVariant &value);

    bool operator==(const Assignment &) const = default;
};

// Where a client stands with their current program
struct ProgramStatus
{
    // "none" | "scheduled" | "active" | "endingSoon" | "expired"
    QString kind = QStringLiteral("none");
    std::optional<Assignment> assignment;
    int daysUntil = 0;      // scheduled
    int daysAgo = 0;        // expired
    int week = 0;           // active / endingSoon (1-based)
    int daysLeft = 0;       // active / endingSoon
    double progress = 0;    // active / endingSoon, 0..1
    QDate lastDay;

    // { kind, assignment (or null), daysUntil, daysAgo, week, daysLeft, progress, lastDay (ms) }
    QVariantMap toVariantMap() const;
    // Reads `kind` and the numbers back (assignment included when it's one)
    static ProgramStatus fromVariant(const QVariant &value);
};

// One of a coach's clients (a row of `coachings` with its assignments). The
// client sees their own coaching the same way.
struct Client
{
    Q_GADGET
    QML_VALUE_TYPE(client)

    // The coaching's id
    Q_PROPERTY(QString id MEMBER id)
    // The client's account, "" for an invitation to an email without one
    Q_PROPERTY(QString userId MEMBER userId)
    Q_PROPERTY(QString coachId MEMBER coachId)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString email MEMBER email)
    Q_PROPERTY(QString phone MEMBER phone)
    Q_PROPERTY(QString goal MEMBER goal)
    // "active" | "paused" | "invited"
    Q_PROPERTY(QString status MEMBER status)
    Q_PROPERTY(double since MEMBER since)
    Q_PROPERTY(double lastCheckIn MEMBER lastCheckIn)
    // Start of the next confirmed session, 0 if none
    Q_PROPERTY(double nextSession MEMBER nextSession)
    // Oldest first
    Q_PROPERTY(QList<Assignment> assignments MEMBER assignments)

public:
    QString id;
    QString userId;
    QString coachId;
    QString name;
    QString email;
    QString phone;
    QString goal;
    QString status;
    double since = 0;
    double lastCheckIn = 0;
    double nextSession = 0;
    QList<Assignment> assignments;

    // Index of the current assignment (the last one not ended), or -1
    int currentIndex() const;
    std::optional<Assignment> currentAssignment() const;
    // Finished assignments, newest first
    QList<Assignment> pastAssignments() const;
    ProgramStatus programStatus(const QDate &today) const;

    // Assigning `assignment` from `today`: the current program moves to the
    // history (completed if it had run out, replaced if running) or is dropped
    // if it hadn't started. A paused client becomes active.
    void assign(const Assignment &assignment, const QDate &today);
    // Ends the current program today (completed if it had run out; dropped if
    // it hadn't started). False if there's none.
    bool endProgram(const QDate &today);
    bool extend(int weeks);

    // filter: "all" | "expired" | "endingSoon" | "none" | "invited" | "paused"
    bool matchesFilter(const QString &filter, const QDate &today) const;

    static Client fromJson(const QJsonObject &row);
    static Client fromVariant(const QVariant &value);

    bool operator==(const Client &) const = default;
};

// A coach as the directory and the client app show them
struct Coach
{
    Q_GADGET
    QML_VALUE_TYPE(coach)

    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString email MEMBER email)
    Q_PROPERTY(QString phone MEMBER phone)
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString city MEMBER city)
    Q_PROPERTY(bool online MEMBER online)
    Q_PROPERTY(bool inPerson MEMBER inPerson)
    Q_PROPERTY(QString studio MEMBER studio)
    Q_PROPERTY(QStringList specialties MEMBER specialties)
    Q_PROPERTY(QString bio MEMBER bio)
    Q_PROPERTY(int years MEMBER years)
    Q_PROPERTY(QStringList certifications MEMBER certifications)
    Q_PROPERTY(QStringList languages MEMBER languages)
    // EUR per session, 0 if not given
    Q_PROPERTY(int priceFrom MEMBER priceFrom)
    Q_PROPERTY(bool accepting MEMBER accepting)
    // "public" | "private"
    Q_PROPERTY(QString visibility MEMBER visibility)
    // { "<weekday>": [ { start, end } ] }, weekday 0 = Sunday, minutes from midnight
    Q_PROPERTY(QVariantMap weeklyHours MEMBER weeklyHours)

public:
    QString id;
    QString name;
    QString email;
    QString phone;
    QString title;
    QString city;
    bool online = false;
    bool inPerson = false;
    QString studio;
    QStringList specialties;
    QString bio;
    int years = 0;
    QStringList certifications;
    QStringList languages;
    int priceFrom = 0;
    bool accepting = false;
    QString visibility;
    QVariantMap weeklyHours;

    bool matches(const QString &query) const;

    // A profiles row with coach_profiles and working_hours embedded
    static Coach fromJson(const QJsonObject &row);
    static Coach fromVariant(const QVariant &value);

    bool operator==(const Coach &) const = default;
};

// A coaching as one side sees it: the client's link to their coach, or a
// request waiting for the coach
struct Coaching
{
    Q_GADGET
    QML_VALUE_TYPE(coaching)

    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString coachId MEMBER coachId)
    Q_PROPERTY(QString email MEMBER email)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString goal MEMBER goal)
    Q_PROPERTY(QString message MEMBER message)
    // "none" | "pending" (request sent) | "invited" | "declined" | "active"
    Q_PROPERTY(QString status MEMBER status)
    // When it started (active) or was sent (pending, declined, invited)
    Q_PROPERTY(double since MEMBER since)

public:
    QString id;
    QString coachId;
    QString email;
    QString name;
    QString goal;
    QString message;
    QString status = QStringLiteral("none");
    double since = 0;

    static Coaching fromJson(const QJsonObject &row);

    bool operator==(const Coaching &) const = default;
};
