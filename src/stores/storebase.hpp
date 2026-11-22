// What every C++ store has in common: it loads the signed-in user's data when
// they log in, empties itself when they log out, and tells QML when its data
// changed (`revision`) or a change was refused (`errorOccurred`).
//
// Bindings that call a store function reading store data must pass the store's
// `revision` as the last argument, e.g.
// ClientStore.search(text, filter, ClientStore.revision), otherwise they don't
// refresh when the data changes.
//
// A derived store implements load() and clearData() and calls start() at the
// end of its constructor.
#pragma once

#include "supabaseclient.hpp"

#include <QJSValue>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#include <functional>

class StoreBase : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS

    // Bumped on every change of the store's data
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged FINAL)

public:
    int revision() const { return m_revision; }
    bool loading() const { return m_pendingLoads > 0; }

signals:
    void revisionChanged();
    void loadingChanged();
    // A change was refused or the data couldn't be loaded (translated message)
    void errorOccurred(const QString &message);

protected:
    explicit StoreBase(QObject *parent = nullptr);

    // Starts following the session. `tables`: reload when one of these
    // changes on the server, from another store or another device
    // (SupabaseClient::notifyChanged, fed by RealtimeClient).
    void start(const QStringList &tables = {});

    // Fetch everything; use beginLoad / isCurrent / endLoadStep
    virtual void load() = 0;
    // Forget the data; return true if there was any
    virtual bool clearData() = 0;

    // Starts a load of `requests` requests; returns its generation
    int beginLoad(int requests);
    // False if a newer load (or a logout) started since `generation`
    bool isCurrent(int generation) const { return generation == m_loadGeneration; }
    // One request of the current load finished
    void endLoadStep();

    // load(), or after the writes still on their way (so it doesn't undo them)
    void requestLoad();

    // Changes go to the server one at a time, in the order they were made
    // (two requests sent together can arrive in either order). `send` makes
    // the request and passes it the callback. If the server refuses, the
    // store shows the error and reloads once the queue is empty.
    using Send = std::function<void(SupabaseClient::Callback)>;
    void write(Send send, std::function<void()> onSuccess = {});
    void writeRpc(const QString &function, const QJsonObject &args, std::function<void()> onSuccess = {});

    QString userId() const;
    void changed();
    // Tells the other stores that `table` changed on the server
    void notify(const QString &table);
    // Translated text for an error code; stores add their own codes
    virtual QString errorText(const QString &code) const;
    // A real JS object (and arrays) for an editor draft that QML changes in
    // place. A QVariantMap would reach QML as list wrappers that copy each
    // element on read, so in-place edits wouldn't stick.
    QJSValue toJs(const QVariantMap &map) const;
    static QString newId();

    SupabaseClient *m_client;

private:
    void onSessionChanged();
    void clear();
    void nextWrite();

    QTimer m_changeDelay;       // groups change notifications into one reload
    QList<std::function<void()>> m_writes;
    bool m_writing = false;
    bool m_reloadAfterWrites = false;
    int m_writeEpoch = 0;       // bumped on logout: late replies are ignored
    QString m_loadedUser;
    QStringList m_tables;
    int m_loadGeneration = 0;
    int m_pendingLoads = 0;
    int m_revision = 0;
};
