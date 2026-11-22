// The signed-in user, as QML sees it: Session.user.name, Session.user.role, ...
// An empty id means nobody is signed in.
#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

struct AuraUser
{
    Q_GADGET
    QML_VALUE_TYPE(auraUser)

    Q_PROPERTY(QString id MEMBER id FINAL)
    Q_PROPERTY(QString name MEMBER name FINAL)
    Q_PROPERTY(QString email MEMBER email FINAL)
    // "coach" or "client"
    Q_PROPERTY(QString role MEMBER role FINAL)

public:
    QString id;
    QString name;
    QString email;
    QString role;

    bool isValid() const { return !id.isEmpty(); }

    // From a row of the profiles table
    static AuraUser fromJson(const QJsonObject &row)
    {
        AuraUser user;
        user.id = row.value(QStringLiteral("id")).toString();
        user.name = row.value(QStringLiteral("name")).toString();
        user.email = row.value(QStringLiteral("email")).toString();
        user.role = row.value(QStringLiteral("role")).toString();
        return user;
    }

    friend bool operator==(const AuraUser &a, const AuraUser &b)
    {
        return a.id == b.id && a.name == b.name && a.email == b.email && a.role == b.role;
    }
    friend bool operator!=(const AuraUser &a, const AuraUser &b) { return !(a == b); }
};
