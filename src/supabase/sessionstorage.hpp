// Keeps the login between launches ("stay logged in"): saves the Supabase
// refresh token in the system's secure storage, through QtKeychain (macOS
// Keychain, Windows Credential Manager; Android Keystore and iOS Keychain
// later).
//
// Only one running copy of the app uses it. Supabase rotates refresh tokens
// and revokes the whole login when a used one comes back, so two copies
// sharing one saved token would log each other out. The first copy takes a
// lock file; later copies start at the login screen and don't save anything.
// AURA_NO_SAVED_LOGIN=1 turns it off too (test drivers).
#pragma once

#include <QObject>
#include <QString>

#include <functional>
#include <memory>
#include <optional>

class QLockFile;

class SessionStorage : public QObject
{
    Q_OBJECT

public:
    // `key` names the entry (one per backend project)
    explicit SessionStorage(const QString &key, QObject *parent = nullptr);
    ~SessionStorage() override;

    bool isEnabled() const { return m_enabled; }

    // The saved token, or "" (none, disabled, or unreadable)
    void read(std::function<void(const QString &token)> done);
    // Saves the token; "" deletes it. Saves run one at a time, in order.
    void save(const QString &token);

private:
    void runNext();

    QString m_service;
    QString m_key;
    std::unique_ptr<QLockFile> m_lock;
    bool m_enabled = false;
    bool m_writing = false;
    std::optional<QString> m_wanted;     // waiting to be written
};
