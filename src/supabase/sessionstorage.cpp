// See sessionstorage.hpp.
#include "sessionstorage.hpp"

#include <qtkeychain/keychain.h>

#include <QCoreApplication>
#include <QDir>
#include <QLockFile>
#include <QLoggingCategory>
#include <QStandardPaths>

#include <utility>

Q_LOGGING_CATEGORY(lcSessionStorage, "aura.session")

SessionStorage::SessionStorage(const QString &key, QObject *parent)
    : QObject(parent)
    , m_service(QCoreApplication::applicationName())
    , m_key(key)
{
    if (qEnvironmentVariableIntValue("AURA_NO_SAVED_LOGIN") == 1) {
        qCInfo(lcSessionStorage) << "saved login turned off (AURA_NO_SAVED_LOGIN)";
        return;
    }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dir);
    m_lock = std::make_unique<QLockFile>(dir + QStringLiteral("/session.lock"));
    // A copy that crashed leaves its lock behind; QLockFile notices that the
    // process is gone and takes it over
    m_enabled = m_lock->tryLock(0);
    if (!m_enabled)
        qCInfo(lcSessionStorage) << "another copy of the app is running: this one won't stay logged in";
}

SessionStorage::~SessionStorage() = default;

void SessionStorage::read(std::function<void(const QString &)> done)
{
    if (!m_enabled) {
        done({});
        return;
    }
    auto *job = new QKeychain::ReadPasswordJob(m_service, this);
    job->setAutoDelete(true);
    job->setKey(m_key);
    connect(job, &QKeychain::Job::finished, this, [job, done] {
        if (job->error() != QKeychain::NoError) {
            if (job->error() != QKeychain::EntryNotFound)
                qCWarning(lcSessionStorage) << "can't read the saved login:" << job->errorString();
            done({});
            return;
        }
        done(job->textData());
    });
    job->start();
}

void SessionStorage::save(const QString &token)
{
    if (!m_enabled)
        return;
    m_wanted = token;
    if (!m_writing)
        runNext();
}

void SessionStorage::runNext()
{
    if (!m_wanted)
        return;
    const QString token = *std::exchange(m_wanted, std::nullopt);
    m_writing = true;
    QKeychain::Job *job;
    if (token.isEmpty()) {
        job = new QKeychain::DeletePasswordJob(m_service, this);
    } else {
        auto *write = new QKeychain::WritePasswordJob(m_service, this);
        write->setTextData(token);
        job = write;
    }
    job->setAutoDelete(true);
    job->setKey(m_key);
    connect(job, &QKeychain::Job::finished, this, [this, job, token] {
        if (job->error() != QKeychain::NoError && !(token.isEmpty() && job->error() == QKeychain::EntryNotFound))
            qCWarning(lcSessionStorage) << "can't save the login:" << job->errorString();
        m_writing = false;
        runNext();
    });
    job->start();
}
