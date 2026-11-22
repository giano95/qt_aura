// See storebase.hpp.
#include "storebase.hpp"

#include "supabaseclient.hpp"

#include <QJSEngine>
#include <QJsonObject>
#include <QUuid>

StoreBase::StoreBase(QObject *parent)
    : QObject(parent)
    , m_client(SupabaseClient::instance())
{
}

void StoreBase::start(const QStringList &tables)
{
    m_tables = tables;
    connect(m_client, &SupabaseClient::sessionChanged, this, &StoreBase::onSessionChanged);
    // Changes often come in bursts (one save touches several tables and rows,
    // and each sends a message): reload once they settle
    m_changeDelay.setSingleShot(true);
    m_changeDelay.setInterval(300);
    connect(&m_changeDelay, &QTimer::timeout, this, &StoreBase::requestLoad);
    connect(m_client, &SupabaseClient::dataChanged, this, [this](const QString &table, QObject *source) {
        if (source == this || m_loadedUser.isEmpty() || !m_client->hasSession())
            return;
        if (table == QLatin1String("*") || m_tables.contains(table))
            m_changeDelay.start();
    });
    // The engine creates a store the first time a screen uses it, which can be
    // after login
    onSessionChanged();
}

void StoreBase::onSessionChanged()
{
    if (!m_client->hasSession()) {
        clear();
        return;
    }
    // sessionChanged also fires on every token refresh: reload only for a new user
    if (m_client->userId() != m_loadedUser) {
        clear();
        m_loadedUser = m_client->userId();
        load();
    }
}

void StoreBase::clear()
{
    ++m_loadGeneration;     // ignore replies still on their way
    ++m_writeEpoch;
    m_changeDelay.stop();
    m_writes.clear();
    m_writing = false;
    m_reloadAfterWrites = false;
    m_loadedUser.clear();
    const bool wasLoading = loading();
    m_pendingLoads = 0;
    if (wasLoading)
        emit loadingChanged();
    if (clearData())
        changed();
}

int StoreBase::beginLoad(int requests)
{
    const bool wasLoading = loading();
    m_pendingLoads = requests;
    if (wasLoading != loading())
        emit loadingChanged();
    return ++m_loadGeneration;
}

void StoreBase::endLoadStep()
{
    if (m_pendingLoads > 0 && --m_pendingLoads == 0)
        emit loadingChanged();
}

QString StoreBase::userId() const
{
    return m_client->userId();
}

void StoreBase::changed()
{
    ++m_revision;
    emit revisionChanged();
}

void StoreBase::requestLoad()
{
    if (m_writing || !m_writes.isEmpty())
        m_reloadAfterWrites = true;
    else if (m_client->hasSession() && !m_loadedUser.isEmpty())
        load();
}

void StoreBase::write(Send send, std::function<void()> onSuccess)
{
    const int epoch = m_writeEpoch;
    m_writes.append([this, epoch, send, onSuccess] {
        send([this, epoch, onSuccess](const SupabaseClient::Reply &reply) {
            if (epoch != m_writeEpoch)
                return;
            m_writing = false;
            if (!reply.ok()) {
                // The local copy may be wrong now: take the server's
                emit errorOccurred(errorText(reply.errorCode));
                m_reloadAfterWrites = true;
            } else if (onSuccess) {
                onSuccess();
            }
            nextWrite();
        });
    });
    if (!m_writing)
        nextWrite();
}

void StoreBase::writeRpc(const QString &function, const QJsonObject &args, std::function<void()> onSuccess)
{
    write([this, function, args](SupabaseClient::Callback done) { m_client->rpc(this, function, args, done); },
          std::move(onSuccess));
}

void StoreBase::nextWrite()
{
    if (m_writes.isEmpty()) {
        if (m_reloadAfterWrites) {
            m_reloadAfterWrites = false;
            requestLoad();
        }
        return;
    }
    m_writing = true;
    const auto job = m_writes.takeFirst();
    job();
}

void StoreBase::notify(const QString &table)
{
    m_client->notifyChanged(table, this);
}

QString StoreBase::errorText(const QString &code) const
{
    if (code == QLatin1String("network"))
        return tr("Can't reach the server. Check your internet connection.");
    if (code == QLatin1String("not_allowed") || code == QLatin1String("42501"))
        return tr("You can't change this.");
    if (code == QLatin1String("not_found"))
        return tr("This was changed or removed in the meantime.");
    if (code == QLatin1String("not_signed_in"))
        return tr("Your session has ended. Please log in again.");
    return tr("Something went wrong (%1). Please try again.").arg(code);
}

QString StoreBase::newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QJSValue StoreBase::toJs(const QVariantMap &map) const
{
    QJSEngine *engine = qjsEngine(this);
    return engine ? engine->toScriptValue(QJsonObject::fromVariantMap(map)) : QJSValue();
}
