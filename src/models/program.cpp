// See program.hpp.
#include "program.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QSet>

#include <algorithm>

namespace {

QString str(const QVariantMap &map, const char *key)
{
    return map.value(QLatin1String(key)).toString();
}

QString str(const QJsonObject &row, const char *key)
{
    return row.value(QLatin1String(key)).toString();
}

double parseTimestamp(const QString &iso)
{
    const QDateTime time = QDateTime::fromString(iso, Qt::ISODateWithMs);
    return time.isValid() ? double(time.toMSecsSinceEpoch()) : 0.0;
}

} // namespace

// ---- Exercise -----------------------------------------------------------------

Exercise Exercise::fromJson(const QJsonObject &row)
{
    Exercise e;
    e.id = str(row, "id");
    e.name = str(row, "name");
    e.muscle = str(row, "muscle");
    e.equipment = str(row, "equipment");
    e.instructions = str(row, "instructions");
    e.videoUrl = str(row, "video_url");
    e.builtIn = row.value(QStringLiteral("coach_id")).isNull();
    return e;
}

// ---- ProgramEntry ---------------------------------------------------------------

const QStringList &ProgramEntry::weeklyKeys()
{
    static const QStringList keys{QStringLiteral("sets"), QStringLiteral("reps"), QStringLiteral("load")};
    return keys;
}

QString ProgramEntry::field(const QString &key) const
{
    if (key == QLatin1String("sets")) return sets;
    if (key == QLatin1String("reps")) return reps;
    if (key == QLatin1String("load")) return load;
    if (key == QLatin1String("rest")) return rest;
    if (key == QLatin1String("notes")) return notes;
    return {};
}

void ProgramEntry::setField(const QString &key, const QString &value)
{
    if (key == QLatin1String("sets")) sets = value;
    else if (key == QLatin1String("reps")) reps = value;
    else if (key == QLatin1String("load")) load = value;
    else if (key == QLatin1String("rest")) rest = value;
    else if (key == QLatin1String("notes")) notes = value;
}

QString ProgramEntry::effective(int week, const QString &key) const
{
    if (week > 0) {
        const QVariantMap change = weeks.value(QString::number(week)).toMap();
        if (change.contains(key))
            return change.value(key).toString();
    }
    return field(key);
}

QStringList ProgramEntry::changedKeys(int week) const
{
    if (week <= 0)
        return {};
    return weeks.value(QString::number(week)).toMap().keys();
}

QList<int> ProgramEntry::changedWeeks() const
{
    QList<int> result;
    for (auto it = weeks.cbegin(); it != weeks.cend(); ++it) {
        bool ok = false;
        const int week = it.key().toInt(&ok);
        if (ok && !it.value().toMap().isEmpty())
            result.append(week);
    }
    std::sort(result.begin(), result.end());
    return result;
}

void ProgramEntry::setWeekValue(int week, const QString &key, const QString &value)
{
    if (week <= 0 || !weeklyKeys().contains(key)) {
        setField(key, value);
        return;
    }
    const QString weekKey = QString::number(week);
    QVariantMap change = weeks.value(weekKey).toMap();
    if (value == field(key))
        change.remove(key);
    else
        change.insert(key, value);
    if (change.isEmpty())
        weeks.remove(weekKey);
    else
        weeks.insert(weekKey, change);
}

void ProgramEntry::dropWeeksAfter(int weekCount)
{
    for (auto it = weeks.begin(); it != weeks.end();) {
        bool ok = false;
        const int week = it.key().toInt(&ok);
        if (!ok || week < 1 || week > weekCount)
            it = weeks.erase(it);
        else
            ++it;
    }
}

ProgramEntry ProgramEntry::fromJson(const QJsonObject &row)
{
    ProgramEntry e;
    e.uid = str(row, "id");
    e.exerciseId = str(row, "exercise_id");
    e.sets = str(row, "sets");
    e.reps = str(row, "reps");
    e.load = str(row, "load");
    e.rest = str(row, "rest");
    e.notes = str(row, "notes");
    e.weeks = row.value(QStringLiteral("weeks")).toObject().toVariantMap();
    return e;
}

ProgramEntry ProgramEntry::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<ProgramEntry>())
        return value.value<ProgramEntry>();
    const QVariantMap map = value.toMap();
    ProgramEntry e;
    e.uid = str(map, "uid");
    e.exerciseId = str(map, "exerciseId");
    e.sets = str(map, "sets");
    e.reps = str(map, "reps");
    e.load = str(map, "load");
    e.rest = str(map, "rest");
    e.notes = str(map, "notes");
    // Week changes from the editor: keep only non-empty string values
    const QVariantMap weekMap = map.value(QStringLiteral("weeks")).toMap();
    for (auto it = weekMap.cbegin(); it != weekMap.cend(); ++it) {
        QVariantMap change;
        const QVariantMap source = it.value().toMap();
        for (auto c = source.cbegin(); c != source.cend(); ++c)
            if (weeklyKeys().contains(c.key()))
                change.insert(c.key(), c.value().toString());
        if (!change.isEmpty())
            e.weeks.insert(it.key(), change);
    }
    return e;
}

QVariantMap ProgramEntry::toVariantMap() const
{
    return {{QStringLiteral("uid"), uid},
            {QStringLiteral("exerciseId"), exerciseId},
            {QStringLiteral("sets"), sets},
            {QStringLiteral("reps"), reps},
            {QStringLiteral("load"), load},
            {QStringLiteral("rest"), rest},
            {QStringLiteral("notes"), notes},
            {QStringLiteral("weeks"), weeks}};
}

QJsonObject ProgramEntry::toSaveJson() const
{
    return {{QStringLiteral("id"), uid},
            {QStringLiteral("exerciseId"), exerciseId},
            {QStringLiteral("sets"), sets},
            {QStringLiteral("reps"), reps},
            {QStringLiteral("load"), load},
            {QStringLiteral("rest"), rest},
            {QStringLiteral("notes"), notes},
            {QStringLiteral("weeks"), QJsonObject::fromVariantMap(weeks)}};
}

// ---- ProgramDay -----------------------------------------------------------------

ProgramDay ProgramDay::fromJson(const QJsonObject &row)
{
    ProgramDay d;
    d.id = str(row, "id");
    d.name = str(row, "name");
    const QJsonArray entries = row.value(QStringLiteral("program_entries")).toArray();
    for (const QJsonValue &entry : entries)
        d.exercises.append(ProgramEntry::fromJson(entry.toObject()));
    return d;
}

ProgramDay ProgramDay::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<ProgramDay>())
        return value.value<ProgramDay>();
    const QVariantMap map = value.toMap();
    ProgramDay d;
    d.id = str(map, "id");
    d.name = str(map, "name");
    const QVariantList entries = map.value(QStringLiteral("exercises")).toList();
    for (const QVariant &entry : entries)
        d.exercises.append(ProgramEntry::fromVariant(entry));
    return d;
}

QVariantMap ProgramDay::toVariantMap() const
{
    QVariantList entries;
    for (const ProgramEntry &entry : exercises)
        entries.append(entry.toVariantMap());
    return {{QStringLiteral("id"), id}, {QStringLiteral("name"), name}, {QStringLiteral("exercises"), entries}};
}

QJsonObject ProgramDay::toSaveJson() const
{
    QJsonArray entries;
    for (const ProgramEntry &entry : exercises)
        entries.append(entry.toSaveJson());
    return {{QStringLiteral("id"), id}, {QStringLiteral("name"), name}, {QStringLiteral("exercises"), entries}};
}

// ---- Program --------------------------------------------------------------------

int Program::clampWeeks(const QVariant &weeks)
{
    bool ok = false;
    const int value = weeks.toString().trimmed().toInt(&ok);
    return std::clamp(ok ? value : 1, 1, maxWeeks);
}

int Program::exerciseCount() const
{
    int count = 0;
    for (const ProgramDay &day : days)
        count += day.exercises.size();
    return count;
}

QList<int> Program::changedWeeks() const
{
    QSet<int> set;
    for (const ProgramDay &day : days)
        for (const ProgramEntry &entry : day.exercises)
            for (int week : entry.changedWeeks())
                set.insert(week);
    QList<int> result(set.cbegin(), set.cend());
    std::sort(result.begin(), result.end());
    return result;
}

int Program::programWeekFor(int assignmentWeek) const
{
    return std::clamp(assignmentWeek, 1, std::max(1, weeks));
}

bool Program::usesExercise(const QString &exerciseId) const
{
    for (const ProgramDay &day : days)
        for (const ProgramEntry &entry : day.exercises)
            if (entry.exerciseId == exerciseId)
                return true;
    return false;
}

Program Program::fromJson(const QJsonObject &row)
{
    Program p;
    p.id = str(row, "id");
    p.name = str(row, "name");
    p.description = str(row, "description");
    p.weeks = clampWeeks(row.value(QStringLiteral("weeks")).toVariant());
    p.updatedAt = parseTimestamp(str(row, "updated_at"));
    const QJsonArray days = row.value(QStringLiteral("program_days")).toArray();
    for (const QJsonValue &day : days)
        p.days.append(ProgramDay::fromJson(day.toObject()));
    return p;
}

Program Program::fromVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<Program>())
        return value.value<Program>();
    const QVariantMap map = value.toMap();
    Program p;
    p.id = str(map, "id");
    p.name = str(map, "name");
    p.description = str(map, "description");
    p.weeks = clampWeeks(map.value(QStringLiteral("weeks")));
    p.updatedAt = map.value(QStringLiteral("updatedAt")).toDouble();
    const QVariantList days = map.value(QStringLiteral("days")).toList();
    for (const QVariant &day : days)
        p.days.append(ProgramDay::fromVariant(day));
    return p;
}

QVariantMap Program::toVariantMap() const
{
    QVariantList dayList;
    for (const ProgramDay &day : days)
        dayList.append(day.toVariantMap());
    return {{QStringLiteral("id"), id},
            {QStringLiteral("name"), name},
            {QStringLiteral("description"), description},
            {QStringLiteral("weeks"), QString::number(weeks)},
            {QStringLiteral("updatedAt"), updatedAt},
            {QStringLiteral("days"), dayList}};
}

QJsonObject Program::toSaveJson() const
{
    QJsonArray dayList;
    for (const ProgramDay &day : days)
        dayList.append(day.toSaveJson());
    return {{QStringLiteral("id"), id},
            {QStringLiteral("name"), name},
            {QStringLiteral("description"), description},
            {QStringLiteral("weeks"), weeks},
            {QStringLiteral("days"), dayList}};
}
