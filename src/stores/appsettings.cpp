// See appsettings.hpp.
#include "appsettings.hpp"

#include <QSettings>

namespace {

const QString kThemeKey = QStringLiteral("appearance/theme");

bool validThemeMode(const QString &mode)
{
    return mode == QLatin1String("system") || mode == QLatin1String("light") || mode == QLatin1String("dark");
}

} // namespace

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    const QString saved = QSettings().value(kThemeKey).toString();
    m_themeMode = validThemeMode(saved) ? saved : QStringLiteral("system");
}

void AppSettings::setThemeMode(const QString &mode)
{
    if (!validThemeMode(mode) || mode == m_themeMode)
        return;
    m_themeMode = mode;
    QSettings().setValue(kThemeKey, mode);
    emit themeModeChanged();
}
