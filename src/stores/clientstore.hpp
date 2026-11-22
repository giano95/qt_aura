// The coach's clients and the programs assigned to them (QML singleton
// `ClientStore`), from the `coachings` and `assignments` tables.
//
// A coach gets their invited, active and paused clients; a client gets their
// own coaching the same way (find it with clientByEmail(Session.user.email)).
// Requests waiting for the coach are in CoachStore.
//
// The current assignment is the last one without an end. Once its last day
// has passed it stays current but counts as expired, until the coach assigns
// a new program or extends it.
//
// Bindings that call a function reading store data pass `revision` last
// (see StoreBase), e.g. ClientStore.search(text, filter, ClientStore.revision).
#pragma once

#include "coaching.hpp"
#include "storebase.hpp"

#include <QtQml/qqmlregistration.h>

class ClientStore : public StoreBase
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<Client> clients READ clients NOTIFY revisionChanged FINAL)

public:
    explicit ClientStore(QObject *parent = nullptr);

    QList<Client> clients() const { return m_clients; }

    // ---- dates (ms at local midnight, like JavaScript dates) ------------------
    Q_INVOKABLE double today() const;
    // Midnight `days` days from today (negative = past)
    Q_INVOKABLE double dayOffset(int days) const;
    Q_INVOKABLE double nextMonday() const;
    // Last day of an assignment (inclusive); takes { start, weeks }
    Q_INVOKABLE double lastDay(const QVariant &assignment) const;
    Q_INVOKABLE int daysBetween(double fromMs, double toMs) const;
    Q_INVOKABLE QString formatDay(double ms) const;
    Q_INVOKABLE QString formatDayLong(double ms) const;
    // "Today", "Yesterday", "3 days ago", "In 2 days", "Never" (for 0)
    Q_INVOKABLE QString relativeDay(double ms) const;

    // ---- reading (pass `revision` last from bindings) -------------------------
    // The client, or null
    Q_INVOKABLE QVariant clientById(const QString &id, const QVariant &revision = {}) const;
    // The coaching of a client account (null if there's none)
    Q_INVOKABLE QVariant clientByEmail(const QString &email, const QVariant &revision = {}) const;
    Q_INVOKABLE QVariant currentAssignment(const QVariant &client) const;
    // Finished assignments, newest first
    Q_INVOKABLE QList<Assignment> pastAssignments(const QVariant &client) const;
    // { kind: "none" | "scheduled" | "active" | "endingSoon" | "expired", assignment,
    //   daysUntil, daysAgo, week, daysLeft, progress, lastDay }
    Q_INVOKABLE QVariantMap programStatus(const QVariant &client) const;
    // Short label and color tone of a status, for chips
    Q_INVOKABLE QString statusText(const QVariant &status) const;
    Q_INVOKABLE QString statusTone(const QVariant &status) const;
    Q_INVOKABLE QString endReasonText(const QString &reason) const;
    // filter: "all" | "expired" | "endingSoon" | "none" | "invited" | "paused"
    Q_INVOKABLE bool matchesFilter(const QVariant &client, const QString &filter) const;
    // By name
    Q_INVOKABLE QList<Client> search(const QString &query, const QString &filter,
                                     const QVariant &revision = {}) const;
    Q_INVOKABLE int count(const QString &filter, const QVariant &revision = {}) const;
    // Clients currently following (or about to start) the program
    Q_INVOKABLE int countForProgram(const QString &programId, const QVariant &revision = {}) const;
    Q_INVOKABLE bool isEmailTaken(const QString &email, const QVariant &revision = {}) const;

    // ---- changes (coach) --------------------------------------------------------
    // Assigns the program from `startMs`; the current program moves to the history
    Q_INVOKABLE void assign(const QString &clientId, const QString &programId, double startMs,
                            const QString &note);
    Q_INVOKABLE void extend(const QString &clientId, int weeks);
    // Ends the current program today (or removes it if it hasn't started)
    Q_INVOKABLE void endProgram(const QString &clientId);
    // Invites an email (private profile); returns the new client's id
    Q_INVOKABLE QString invite(const QString &name, const QString &email, const QString &goal);

protected:
    void load() override;
    bool clearData() override;
    QString errorText(const QString &code) const override;

private:
    QDate todayDate() const { return QDate::currentDate(); }
    Client *find(const QString &id);

    QList<Client> m_clients;
    // client account id -> start of their next confirmed session
    QHash<QString, double> m_nextSessions;
};
