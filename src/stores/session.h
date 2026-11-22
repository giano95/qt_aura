// Authentication state for the app (QML singleton `Session`).
//
// Same API the Phase 0 QML mock had (login / signup / logout, user, busy,
// lastError), now backed by Supabase Auth: logging in fetches the user's row
// from the profiles table, which says whether they're a coach or a client.
#pragma once

#include "aurauser.h"

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class SupabaseClient;

class Session : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Empty (id "") when logged out
    Q_PROPERTY(AuraUser user READ user NOTIFY userChanged FINAL)
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY userChanged FINAL)
    Q_PROPERTY(bool isCoach READ isCoach NOTIFY userChanged FINAL)
    Q_PROPERTY(QString firstName READ firstName NOTIFY userChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged FINAL)

public:
    explicit Session(QObject *parent = nullptr);

    AuraUser user() const { return m_user; }
    bool loggedIn() const { return m_user.isValid(); }
    bool isCoach() const { return loggedIn() && m_user.role == QLatin1String("coach"); }
    QString firstName() const;
    bool busy() const { return m_busy; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void login(const QString &email, const QString &password);
    // role: "coach" or "client"
    Q_INVOKABLE void signup(const QString &name, const QString &email, const QString &password,
                            const QString &role);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearError();
    Q_INVOKABLE bool isValidEmail(const QString &email) const;

signals:
    void userChanged();
    void busyChanged();
    void lastErrorChanged();

private:
    void loadProfile();
    void fail(const QString &message);
    void setUser(const AuraUser &user);
    void setBusy(bool busy);
    void setLastError(const QString &message);
    // Translated text for an auth error code from SupabaseClient::Reply
    static QString errorText(const QString &code);

    SupabaseClient *m_client;
    AuraUser m_user;
    bool m_busy = false;
    QString m_lastError;
};
