// The app's own settings (QML singleton `AppSettings`), saved on this device
// with QSettings, so they apply before logging in and differ per computer or
// phone. Nothing here goes to the server.
//
//   themeMode: "system" (follow the OS) | "light" | "dark"; Theme.dark reads it
#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged FINAL)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString themeMode() const { return m_themeMode; }
    // Unknown values are ignored
    void setThemeMode(const QString &mode);

signals:
    void themeModeChanged();

private:
    QString m_themeMode;
};
