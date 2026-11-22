#include "supabaseclient.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Aura");
    QGuiApplication::setOrganizationName("Aura");

    // Backend connection, shared by the C++ stores. Declared before the engine
    // so it outlives the QML singletons that use it.
    SupabaseClient supabase(QStringLiteral(AURA_SUPABASE_URL), QStringLiteral(AURA_SUPABASE_KEY));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("qt_aura", "Main");

    return QGuiApplication::exec();
}
