pragma Singleton
import QtQuick

// Authentication state for the app.
//
// PHASE 0: this is a mock. Accounts live in memory and a Timer simulates
// network latency. In Phase 2 the same API (login / signup / logout, user,
// busy, lastError) will be backed by a C++ AuthService talking to the cloud
// backend, so the screens will not need to change.
QtObject {
    id: session

    // { id, name, email, role } where role is "coach" or "client"; null when logged out
    property var user: null
    readonly property bool loggedIn: user !== null
    readonly property bool isCoach: loggedIn && user.role === "coach"
    readonly property string firstName: loggedIn ? user.name.split(" ")[0] : ""

    property bool busy: false
    property string lastError: ""

    function login(email, password) {
        _start({ kind: "login", email: email, password: password })
    }

    function signup(name, email, password, role) {
        _start({ kind: "signup", name: name, email: email, password: password, role: role })
    }

    function logout() {
        user = null
    }

    function clearError() {
        lastError = ""
    }

    function isValidEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
    }

    // ---- mock backend -------------------------------------------------------

    property var _accounts: [
        { id: 1, name: "Giulia Rossi", email: "coach@aura.app", password: "password", role: "coach" },
        { id: 2, name: "Luca Bianchi", email: "client@aura.app", password: "password", role: "client" }
    ]
    property var _pending: null
    property Timer _latency: Timer {
        interval: 700
        onTriggered: session._complete()
    }

    function _start(request) {
        if (busy)
            return
        lastError = ""
        busy = true
        _pending = request
        _latency.restart()
    }

    function _publicUser(account) {
        return { id: account.id, name: account.name, email: account.email, role: account.role }
    }

    function _complete() {
        const req = _pending
        _pending = null
        busy = false

        const email = req.email.trim().toLowerCase()
        const existing = _accounts.find(a => a.email === email)

        if (req.kind === "login") {
            if (!existing || existing.password !== req.password) {
                lastError = qsTr("Incorrect email or password.")
                return
            }
            user = _publicUser(existing)
            return
        }

        if (existing) {
            lastError = qsTr("An account with this email already exists. Try logging in.")
            return
        }
        const account = {
            id: _accounts.length + 1,
            name: req.name.trim(),
            email: email,
            password: req.password,
            role: req.role
        }
        _accounts = _accounts.concat([account])
        user = _publicUser(account)
    }
}
