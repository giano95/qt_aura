// Coach directory and the link between a client and their coach (QML
// singleton `CoachStore`), from `profiles` + `coach_profiles` + `working_hours`
// and the `coachings` table.
//
// How clients and coaches get together:
//   - public coaches are listed in the directory; clients send a request and
//     the coach accepts or declines it
//   - private coaches aren't listed; they invite clients by email
//     (ClientStore.invite) and the client accepts or declines the invitation
//
// The coach's answer arrives live (RealtimeClient); `requestAccepted` fires
// when the store sees the client's request turn active.
//
// Bindings that call a function reading store data pass `revision` last
// (see StoreBase), e.g. CoachStore.coachById(id, CoachStore.revision).
#pragma once

#include "coaching.hpp"
#include "storebase.hpp"

#include <QtQml/qqmlregistration.h>

class CoachStore : public StoreBase
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Every coach the user can see: public ones, their own coach, themselves
    Q_PROPERTY(QList<Coach> coaches READ coaches NOTIFY revisionChanged FINAL)
    // The logged-in client's link to a coach (status "none" without one);
    // null for coach accounts
    Q_PROPERTY(QVariant myRelation READ myRelation NOTIFY revisionChanged FINAL)
    // The logged-in client's coach, or null
    Q_PROPERTY(QVariant myCoach READ myCoach NOTIFY revisionChanged FINAL)
    // The logged-in coach's own profile, or null
    Q_PROPERTY(QVariant myProfile READ myProfile NOTIFY revisionChanged FINAL)
    Q_PROPERTY(bool isPublic READ isPublic NOTIFY revisionChanged FINAL)
    // Requests waiting for the logged-in coach, newest first
    Q_PROPERTY(QList<Coaching> pendingRequests READ pendingRequests NOTIFY revisionChanged FINAL)

public:
    explicit CoachStore(QObject *parent = nullptr);

    QList<Coach> coaches() const { return m_coaches; }
    QVariant myRelation() const;
    QVariant myCoach() const;
    QVariant myProfile() const;
    bool isPublic() const;
    QList<Coaching> pendingRequests() const { return m_requests; }

    // ---- reading (pass `revision` last from bindings) -------------------------
    // The coach, or null
    Q_INVOKABLE QVariant coachById(const QString &id, const QVariant &revision = {}) const;
    // Public coaches; mode: "all" | "online" | "inPerson". Accepting first, then by name.
    Q_INVOKABLE QList<Coach> search(const QString &query, const QString &mode,
                                    const QVariant &revision = {}) const;
    // "Mon–Fri 09:00–18:00", "Sat 09:00–13:00", ... (consecutive days with the
    // same hours grouped)
    Q_INVOKABLE QStringList hoursSummary(const QVariant &coach) const;
    Q_INVOKABLE QString modesText(const QVariant &coach) const;

    // ---- changes (logged-in client) ---------------------------------------------
    // Sends a request to a public coach
    Q_INVOKABLE void request(const QString &coachId, const QString &goal, const QString &message);
    Q_INVOKABLE void cancelRequest();
    // After a decline, back to choosing a coach
    Q_INVOKABLE void dismissDeclined();
    Q_INVOKABLE void acceptInvitation();
    Q_INVOKABLE void declineInvitation();
    // Ends the coaching; the current program ends today
    Q_INVOKABLE void leave();

    // ---- changes (logged-in coach) ----------------------------------------------
    Q_INVOKABLE void acceptRequest(const QString &coachingId);
    Q_INVOKABLE void declineRequest(const QString &coachingId);
    // "public" | "private". Going private declines the requests still waiting.
    Q_INVOKABLE void setVisibility(const QString &visibility);

signals:
    // The client's request was accepted (seen on a reload)
    void requestAccepted(const QString &coachName);

protected:
    void load() override;
    bool clearData() override;
    QString errorText(const QString &code) const override;

private:
    bool isCoachAccount() const;
    const Coach *findCoach(const QString &id) const;
    void setRelation(const Coaching &relation);
    // Calls `function`; on success tells the other stores that coachings changed
    void rpc(const QString &function, const QJsonObject &args, bool coachingsChanged);

    QList<Coach> m_coaches;
    Coaching m_relation;            // client side
    QList<Coaching> m_requests;     // coach side
};
