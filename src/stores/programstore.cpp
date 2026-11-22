// See programstore.h.
#include "programstore.h"

#include "supabaseclient.h"

#include <QDate>
#include <QDateTime>
#include <QJSEngine>
#include <QJsonArray>
#include <QLocale>
#include <QUuid>

#include <algorithm>

namespace {

bool containsText(const QString &haystack, const QString &needle)
{
    return haystack.contains(needle, Qt::CaseInsensitive);
}

} // namespace

ProgramStore::ProgramStore(QObject *parent)
    : QObject(parent)
    , m_client(SupabaseClient::instance())
{
    connect(m_client, &SupabaseClient::sessionChanged, this, &ProgramStore::onSessionChanged);
    // The engine creates the store the first time a screen uses it, which can
    // be after login
    onSessionChanged();
}

QStringList ProgramStore::muscleGroups() const
{
    static const QStringList groups{
        QStringLiteral("Chest"), QStringLiteral("Back"), QStringLiteral("Legs"),
        QStringLiteral("Glutes"), QStringLiteral("Shoulders"), QStringLiteral("Arms"),
        QStringLiteral("Core"), QStringLiteral("Full body"), QStringLiteral("Cardio")};
    return groups;
}

QStringList ProgramStore::equipmentTypes() const
{
    static const QStringList types{
        QStringLiteral("Bodyweight"), QStringLiteral("Dumbbells"), QStringLiteral("Barbell"),
        QStringLiteral("Kettlebell"), QStringLiteral("Machine"), QStringLiteral("Cable"),
        QStringLiteral("Bands"), QStringLiteral("Other")};
    return types;
}

// ---- loading ------------------------------------------------------------------

void ProgramStore::onSessionChanged()
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

void ProgramStore::load()
{
    const int generation = ++m_loadGeneration;
    m_pendingLoads = 2;
    emit loadingChanged();
    const auto done = [this] {
        if (--m_pendingLoads == 0)
            emit loadingChanged();
    };

    QUrlQuery exerciseQuery;
    exerciseQuery.addQueryItem(QStringLiteral("select"),
                               QStringLiteral("id,coach_id,name,muscle,equipment,instructions,video_url"));
    exerciseQuery.addQueryItem(QStringLiteral("order"), QStringLiteral("name.asc"));
    m_client->select(this, QStringLiteral("exercises"), exerciseQuery,
                     [this, generation, done](const SupabaseClient::Reply &reply) {
                         if (generation != m_loadGeneration)
                             return;
                         done();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_exercises.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows)
                             m_exercises.append(Exercise::fromJson(row.toObject()));
                         changed();
                     });

    QUrlQuery programQuery;
    programQuery.addQueryItem(
        QStringLiteral("select"),
        QStringLiteral("id,name,description,weeks,updated_at,"
                       "program_days(id,name,position,"
                       "program_entries(id,position,exercise_id,sets,reps,load,rest,notes,weeks))"));
    programQuery.addQueryItem(QStringLiteral("program_days.order"), QStringLiteral("position.asc"));
    programQuery.addQueryItem(QStringLiteral("program_days.program_entries.order"), QStringLiteral("position.asc"));
    m_client->select(this, QStringLiteral("programs"), programQuery,
                     [this, generation, done](const SupabaseClient::Reply &reply) {
                         if (generation != m_loadGeneration)
                             return;
                         done();
                         if (!reply.ok()) {
                             emit errorOccurred(errorText(reply.errorCode));
                             return;
                         }
                         m_programs.clear();
                         const QJsonArray rows = reply.data.array();
                         for (const QJsonValue &row : rows)
                             m_programs.append(Program::fromJson(row.toObject()));
                         changed();
                     });
}

void ProgramStore::clear()
{
    ++m_loadGeneration;     // ignore replies still on their way
    m_loadedUser.clear();
    const bool wasLoading = loading();
    m_pendingLoads = 0;
    if (wasLoading)
        emit loadingChanged();
    if (m_exercises.isEmpty() && m_programs.isEmpty())
        return;
    m_exercises.clear();
    m_programs.clear();
    changed();
}

void ProgramStore::changed()
{
    ++m_revision;
    emit revisionChanged();
}

// A write was refused: the local copy may be wrong, so take the server's
void ProgramStore::fail(const QString &code)
{
    emit errorOccurred(errorText(code));
    if (m_client->hasSession())
        load();
}

QString ProgramStore::newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QString ProgramStore::errorText(const QString &code)
{
    if (code == QLatin1String("network"))
        return tr("Can't reach the server. Check your internet connection.");
    if (code == QLatin1String("23503"))     // foreign key: exercise still used
        return tr("This exercise is used in a program, so it can't be deleted.");
    if (code == QLatin1String("23505"))     // unique: exercise name
        return tr("An exercise with this name already exists.");
    if (code == QLatin1String("invalid_program"))
        return tr("The program couldn't be saved: check its name and exercises.");
    if (code == QLatin1String("not_allowed") || code == QLatin1String("42501"))
        return tr("You can't change this.");
    return tr("Something went wrong (%1). Please try again.").arg(code);
}

// ---- exercises ------------------------------------------------------------------

QVariant ProgramStore::exerciseById(const QString &id, const QVariant &) const
{
    for (const Exercise &e : m_exercises)
        if (e.id == id)
            return QVariant::fromValue(e);
    return QVariant::fromValue(nullptr);
}

QList<Exercise> ProgramStore::searchExercises(const QString &query, const QString &muscle, const QVariant &) const
{
    const QString q = query.trimmed();
    QList<Exercise> result;
    for (const Exercise &e : m_exercises) {
        if (!muscle.isEmpty() && e.muscle != muscle)
            continue;
        if (!q.isEmpty() && !containsText(e.name, q) && !containsText(e.equipment, q))
            continue;
        result.append(e);
    }
    std::sort(result.begin(), result.end(), [](const Exercise &a, const Exercise &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    return result;
}

int ProgramStore::countByMuscle(const QString &muscle, const QVariant &) const
{
    if (muscle.isEmpty())
        return m_exercises.size();
    return int(std::count_if(m_exercises.cbegin(), m_exercises.cend(),
                             [&](const Exercise &e) { return e.muscle == muscle; }));
}

bool ProgramStore::isExerciseNameTaken(const QString &name, const QString &exceptId, const QVariant &) const
{
    const QString n = name.trimmed();
    return std::any_of(m_exercises.cbegin(), m_exercises.cend(), [&](const Exercise &e) {
        return e.id != exceptId && e.name.compare(n, Qt::CaseInsensitive) == 0;
    });
}

int ProgramStore::usageCount(const QString &exerciseId, const QVariant &) const
{
    return int(std::count_if(m_programs.cbegin(), m_programs.cend(),
                             [&](const Program &p) { return p.usesExercise(exerciseId); }));
}

QString ProgramStore::saveExercise(const QVariantMap &input)
{
    Exercise exercise;
    exercise.id = input.value(QStringLiteral("id")).toString();
    const bool isNew = exercise.id.isEmpty();
    if (isNew) {
        exercise.id = newId();
    } else {
        const auto existing = std::find_if(m_exercises.cbegin(), m_exercises.cend(),
                                           [&](const Exercise &e) { return e.id == exercise.id; });
        if (existing == m_exercises.cend() || existing->builtIn) {
            emit errorOccurred(tr("Built-in exercises can't be changed."));
            return exercise.id;
        }
    }
    exercise.name = input.value(QStringLiteral("name")).toString().trimmed();
    exercise.muscle = input.value(QStringLiteral("muscle")).toString();
    exercise.equipment = input.value(QStringLiteral("equipment")).toString();
    exercise.instructions = input.value(QStringLiteral("instructions")).toString().trimmed();
    exercise.videoUrl = input.value(QStringLiteral("videoUrl")).toString().trimmed();

    m_exercises.removeIf([&](const Exercise &e) { return e.id == exercise.id; });
    m_exercises.append(exercise);
    changed();

    QJsonObject row{{QStringLiteral("name"), exercise.name},
                    {QStringLiteral("muscle"), exercise.muscle},
                    {QStringLiteral("equipment"), exercise.equipment},
                    {QStringLiteral("instructions"), exercise.instructions},
                    {QStringLiteral("video_url"), exercise.videoUrl}};
    const auto done = [this](const SupabaseClient::Reply &reply) {
        if (!reply.ok())
            fail(reply.errorCode);
    };
    if (isNew) {
        row.insert(QStringLiteral("id"), exercise.id);
        row.insert(QStringLiteral("coach_id"), m_client->userId());
        m_client->insert(this, QStringLiteral("exercises"), row, done);
    } else {
        QUrlQuery filter;
        filter.addQueryItem(QStringLiteral("id"), QStringLiteral("eq.") + exercise.id);
        m_client->update(this, QStringLiteral("exercises"), filter, row, done);
    }
    return exercise.id;
}

bool ProgramStore::deleteExercise(const QString &id)
{
    const auto it = std::find_if(m_exercises.cbegin(), m_exercises.cend(),
                                 [&](const Exercise &e) { return e.id == id; });
    if (it == m_exercises.cend() || it->builtIn || usageCount(id) > 0)
        return false;
    m_exercises.removeIf([&](const Exercise &e) { return e.id == id; });
    changed();
    QUrlQuery filter;
    filter.addQueryItem(QStringLiteral("id"), QStringLiteral("eq.") + id);
    m_client->remove(this, QStringLiteral("exercises"), filter, [this](const SupabaseClient::Reply &reply) {
        if (!reply.ok())
            fail(reply.errorCode);
    });
    return true;
}

// ---- programs -------------------------------------------------------------------

QList<Program> ProgramStore::searchPrograms(const QString &query, const QVariant &) const
{
    const QString q = query.trimmed();
    QList<Program> result;
    for (const Program &p : m_programs)
        if (q.isEmpty() || containsText(p.name, q) || containsText(p.description, q))
            result.append(p);
    std::sort(result.begin(), result.end(),
              [](const Program &a, const Program &b) { return a.updatedAt > b.updatedAt; });
    return result;
}

// Through QJsonObject: that yields real JS objects and arrays all the way down,
// whereas a QVariantMap's nested lists become list wrappers that hand out a new
// copy of each element on every read.
QJSValue ProgramStore::toJs(const QVariantMap &map) const
{
    QJSEngine *engine = qjsEngine(this);
    return engine ? engine->toScriptValue(QJsonObject::fromVariantMap(map)) : QJSValue();
}

QVariantMap ProgramStore::programDraft(const QString &id) const
{
    for (const Program &p : m_programs)
        if (p.id == id)
            return p.toVariantMap();
    return emptyProgramDraft();
}

QVariantMap ProgramStore::emptyProgramDraft() const
{
    QVariantMap draft = Program{}.toVariantMap();
    draft.insert(QStringLiteral("weeks"), QStringLiteral("4"));
    draft.insert(QStringLiteral("updatedAt"), double(QDateTime::currentMSecsSinceEpoch()));
    draft.insert(QStringLiteral("days"), QVariantList{dayDraft(1)});
    return draft;
}

QVariantMap ProgramStore::dayDraft(int number) const
{
    ProgramDay day;
    day.id = newId();
    day.name = tr("Day %1").arg(number);
    return day.toVariantMap();
}

QVariantMap ProgramStore::entryDraft(const QString &exerciseId) const
{
    ProgramEntry entry;
    entry.uid = newId();
    entry.exerciseId = exerciseId;
    entry.sets = QStringLiteral("3");
    entry.reps = QStringLiteral("10");
    entry.rest = QStringLiteral("60");
    return entry.toVariantMap();
}

QJSValue ProgramStore::cloneProgram(const QString &id) const
{
    return toJs(programDraft(id));
}

QJSValue ProgramStore::newProgramDraft() const
{
    return toJs(emptyProgramDraft());
}

QJSValue ProgramStore::newDay(int number) const
{
    return toJs(dayDraft(number));
}

QJSValue ProgramStore::newEntry(const QString &exerciseId) const
{
    return toJs(entryDraft(exerciseId));
}

QJSValue ProgramStore::duplicateDay(const QVariant &value) const
{
    ProgramDay day = ProgramDay::fromVariant(value);
    day.id = newId();
    day.name = tr("%1 (copy)").arg(day.name);
    for (ProgramEntry &entry : day.exercises)
        entry.uid = newId();
    return toJs(day.toVariantMap());
}

QString ProgramStore::saveProgram(const QVariant &draft)
{
    Program program = Program::fromVariant(draft);
    if (program.id.isEmpty())
        program.id = newId();
    program.name = program.name.trimmed();
    program.description = program.description.trimmed();
    program.updatedAt = double(QDateTime::currentMSecsSinceEpoch());
    for (ProgramDay &day : program.days) {
        if (day.id.isEmpty())
            day.id = newId();
        for (ProgramEntry &entry : day.exercises) {
            if (entry.uid.isEmpty())
                entry.uid = newId();
            entry.dropWeeksAfter(program.weeks);
        }
    }

    m_programs.removeIf([&](const Program &p) { return p.id == program.id; });
    m_programs.append(program);
    changed();

    m_client->rpc(this, QStringLiteral("save_program"), {{QStringLiteral("p"), program.toSaveJson()}},
                  [this](const SupabaseClient::Reply &reply) {
                      if (!reply.ok())
                          fail(reply.errorCode);
                  });
    return program.id;
}

void ProgramStore::deleteProgram(const QString &id)
{
    m_programs.removeIf([&](const Program &p) { return p.id == id; });
    changed();
    QUrlQuery filter;
    filter.addQueryItem(QStringLiteral("id"), QStringLiteral("eq.") + id);
    m_client->remove(this, QStringLiteral("programs"), filter, [this](const SupabaseClient::Reply &reply) {
        if (!reply.ok())
            fail(reply.errorCode);
    });
}

// ---- per-week values ----------------------------------------------------------

int ProgramStore::exerciseCount(const QVariant &program) const
{
    return Program::fromVariant(program).exerciseCount();
}

int ProgramStore::weekCount(const QVariant &program, const QVariant &) const
{
    return Program::fromVariant(program).weeks;
}

QString ProgramStore::effective(const QVariant &entry, int week, const QString &key) const
{
    return ProgramEntry::fromVariant(entry).effective(week, key);
}

QStringList ProgramStore::changedKeys(const QVariant &entry, int week, const QVariant &) const
{
    return ProgramEntry::fromVariant(entry).changedKeys(week);
}

QList<int> ProgramStore::entryChangedWeeks(const QVariant &entry, const QVariant &) const
{
    return ProgramEntry::fromVariant(entry).changedWeeks();
}

QList<int> ProgramStore::programChangedWeeks(const QVariant &program, const QVariant &) const
{
    return Program::fromVariant(program).changedWeeks();
}

void ProgramStore::setWeekValue(QJSValue entry, int week, const QString &key, const QString &value) const
{
    ProgramEntry typed = ProgramEntry::fromVariant(entry.toVariant());
    typed.setWeekValue(week, key, value);
    QJSEngine *engine = qjsEngine(this);
    if (!engine)
        return;
    // Write back only what can change, keeping the JS object (and the editor's
    // references to it) the same
    entry.setProperty(key, typed.field(key));
    entry.setProperty(QStringLiteral("weeks"), engine->toScriptValue(QJsonObject::fromVariantMap(typed.weeks)));
}

// ---- display helpers ------------------------------------------------------------

int ProgramStore::programWeekFor(const QVariant &program, int assignmentWeek) const
{
    return Program::fromVariant(program).programWeekFor(assignmentWeek);
}

QString ProgramStore::prescriptionText(const QVariant &value, int week) const
{
    const ProgramEntry entry = ProgramEntry::fromVariant(value);
    const QString sets = entry.effective(week, QStringLiteral("sets"));
    const QString reps = entry.effective(week, QStringLiteral("reps"));
    if (sets.isEmpty() || sets == QLatin1String("1"))
        return reps;
    return reps.isEmpty() ? tr("%1 sets").arg(sets) : tr("%1 × %2").arg(sets, reps);
}

QString ProgramStore::restText(const QVariant &value) const
{
    const int s = value.toString().toInt();
    if (s <= 0)
        return {};
    if (s < 120 && s % 60 != 0)
        return tr("%1 s").arg(s);
    const int m = s / 60;
    const int r = s % 60;
    return r == 0 ? tr("%1 min").arg(m) : tr("%1 min %2 s").arg(m).arg(r);
}

QString ProgramStore::editedLabel(double ms) const
{
    const QDateTime edited = QDateTime::fromMSecsSinceEpoch(qint64(ms));
    const qint64 days = qint64(QDateTime::currentMSecsSinceEpoch() - qint64(ms)) / 86400000;
    if (days <= 0)
        return tr("Edited today");
    if (days == 1)
        return tr("Edited yesterday");
    if (days < 30)
        return tr("Edited %1 days ago").arg(days);
    return tr("Edited %1").arg(QLocale().toString(edited.date(), QStringLiteral("d MMM yyyy")));
}
