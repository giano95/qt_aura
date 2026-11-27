// See program.hpp.
#include "program.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QRegularExpression>

#include <algorithm>
#include <utility>

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

const QList<std::pair<QString, QStringList>> &Exercise::muscleTree()
{
    static const QList<std::pair<QString, QStringList>> tree{
        {QStringLiteral("Chest"),
         {QStringLiteral("Upper Chest"), QStringLiteral("Middle Chest"), QStringLiteral("Lower Chest")}},
        {QStringLiteral("Back"),
         {QStringLiteral("Upper Traps"), QStringLiteral("Lower Traps"), QStringLiteral("Lats"),
          QStringLiteral("Lower Back")}},
        {QStringLiteral("Legs"),
         {QStringLiteral("Quads"), QStringLiteral("Hamstrings"), QStringLiteral("Glutes"),
          QStringLiteral("Abductors"), QStringLiteral("Adductors"), QStringLiteral("Calves")}},
        {QStringLiteral("Shoulders"),
         {QStringLiteral("Front Delt"), QStringLiteral("Middle Delt"), QStringLiteral("Rear Delt")}},
        {QStringLiteral("Arms"),
         {QStringLiteral("Biceps"), QStringLiteral("Brachialis"), QStringLiteral("Triceps"),
          QStringLiteral("Forearm")}},
        {QStringLiteral("Abs"),
         {QStringLiteral("Upper Abs"), QStringLiteral("Lower Abs"), QStringLiteral("Obliques")}},
        {QStringLiteral("Cardio"), {}},
    };
    return tree;
}

QStringList Exercise::partsOf(const QString &group)
{
    for (const auto &[name, parts] : muscleTree())
        if (name == group)
            return parts;
    return {};
}

void Exercise::normalizeMuscles()
{
    QStringList groups;
    QStringList parts;
    for (const auto &[group, groupParts] : muscleTree()) {
        if (!muscles.contains(group))
            continue;
        groups.append(group);
        for (const QString &part : groupParts)
            if (subMuscles.contains(part))
                parts.append(part);
    }
    muscles = groups;
    subMuscles = parts;
}

QStringList Exercise::groupsMissingParts() const
{
    QStringList missing;
    for (const auto &[group, groupParts] : muscleTree()) {
        if (!muscles.contains(group) || groupParts.isEmpty())
            continue;
        if (std::none_of(groupParts.cbegin(), groupParts.cend(),
                         [&](const QString &part) { return subMuscles.contains(part); }))
            missing.append(group);
    }
    return missing;
}

QStringList Exercise::muscleTags() const
{
    QStringList tags;
    for (const auto &[group, groupParts] : muscleTree()) {
        if (!muscles.contains(group))
            continue;
        const qsizetype before = tags.size();
        for (const QString &part : groupParts)
            if (subMuscles.contains(part))
                tags.append(part);
        if (tags.size() == before)
            tags.append(group);
    }
    return tags;
}

Exercise Exercise::fromJson(const QJsonObject &row)
{
    Exercise e;
    e.id = str(row, "id");
    e.name = str(row, "name");
    for (const QJsonValue &v : row.value(QStringLiteral("muscles")).toArray())
        e.muscles.append(v.toString());
    for (const QJsonValue &v : row.value(QStringLiteral("sub_muscles")).toArray())
        e.subMuscles.append(v.toString());
    e.equipment = str(row, "equipment");
    e.instructions = str(row, "instructions");
    e.videoUrl = str(row, "video_url");
    e.image = str(row, "image");
    e.builtIn = row.value(QStringLiteral("coach_id")).isNull();
    return e;
}

// ---- ProgramEntry ---------------------------------------------------------------

const QStringList &ProgramEntry::weeklyKeys()
{
    static const QStringList keys{QStringLiteral("sets"), QStringLiteral("reps"), QStringLiteral("load")};
    return keys;
}

// ---- field modes (reps / time, load / RPE / 1RM %) ----

namespace {

const QString kOther = QStringLiteral("other");

// How one mode stores its value: prefix + number part + suffix. The number
// part is a number or a range ("8–10"); reps also allow "20+".
struct FieldMode
{
    QString mode;
    QString prefix;
    QString suffix;
    QString body;        // regex for the number part (en dash for ranges)
};

const QList<FieldMode> &fieldModes()
{
    static const QString dec = QStringLiteral("\\d{1,3}(?:[.,]\\d{1,2})?");
    static const QString rpe = QStringLiteral("(?:10|[1-9])(?:[.,]5)?");
    static const QList<FieldMode> modes{
        {QStringLiteral("reps"), {}, {}, QStringLiteral("\\d{1,3}(?:–\\d{1,3}|\\+)?")},
        {QStringLiteral("time"), {}, QStringLiteral(" s"), QStringLiteral("\\d{1,4}(?:–\\d{1,4})?")},
        {QStringLiteral("load"), {}, QStringLiteral(" kg"), dec + QStringLiteral("(?:–") + dec + QStringLiteral(")?")},
        {QStringLiteral("rpe"), QStringLiteral("RPE "), {}, rpe + QStringLiteral("(?:–") + rpe + QStringLiteral(")?")},
        {QStringLiteral("percent"), {}, QStringLiteral("%"), QStringLiteral("\\d{1,3}(?:–\\d{1,3})?")},
    };
    return modes;
}

const FieldMode *findMode(const QString &mode)
{
    for (const FieldMode &m : fieldModes())
        if (m.mode == mode)
            return &m;
    return nullptr;
}

// Modes of a field, the first being the default (and the mode of "")
QStringList modesFor(const QString &key)
{
    if (key == QLatin1String("reps"))
        return {QStringLiteral("reps"), QStringLiteral("time")};
    if (key == QLatin1String("load"))
        return {QStringLiteral("load"), QStringLiteral("rpe"), QStringLiteral("percent")};
    return {};
}

// Trimmed, with "-" as an en dash and no spaces around it ("8 - 10" -> "8–10")
QString normalized(const QString &value)
{
    static const QRegularExpression dash(QStringLiteral("\\s*[-–]\\s*"));
    QString result = value.trimmed();
    result.replace(dash, QStringLiteral("–"));
    return result;
}

// Whether `value` is in `mode`'s stored form; `body` gets its number part
bool matches(const FieldMode &mode, const QString &value, QString *body = nullptr)
{
    const QRegularExpression re(QStringLiteral("^") + QRegularExpression::escape(mode.prefix)
                                    + QStringLiteral("(") + mode.body + QStringLiteral(")")
                                    + QRegularExpression::escape(mode.suffix) + QStringLiteral("$"),
                                QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(normalized(value));
    if (m.hasMatch() && body)
        *body = m.captured(1);
    return m.hasMatch();
}

// The number part of free text for `mode` ("1 min" -> 60 for time, "2 × 12 kg"
// -> 12 for load, "Deload · 60%" -> 60 for 1RM %); "" when there's none
QString extractFor(const QString &mode, const QString &text)
{
    static const QString num = QStringLiteral("(\\d+(?:[.,]\\d+)?(?:\\s*[-–]\\s*\\d+(?:[.,]\\d+)?)?)");
    const auto find = [&text](const QString &pattern) {
        const QRegularExpressionMatch m =
            QRegularExpression(pattern, QRegularExpression::CaseInsensitiveOption).match(text);
        return m.hasMatch() ? m.captured(1) : QString();
    };
    if (mode == QLatin1String("reps")) {
        static const QRegularExpression lead(QStringLiteral("^\\s*(\\d+(?:\\s*[-–]\\s*\\d+)?\\s*\\+?)"));
        const QRegularExpressionMatch m = lead.match(text);
        return m.hasMatch() ? m.captured(1) : QString();
    }
    if (mode == QLatin1String("time")) {
        static const QRegularExpression lead(
            QStringLiteral("^\\s*(\\d+)(?:\\s*[-–]\\s*(\\d+))?\\s*(min)?"), QRegularExpression::CaseInsensitiveOption);
        const QRegularExpressionMatch m = lead.match(text);
        if (!m.hasMatch())
            return {};
        const int factor = m.captured(3).isEmpty() ? 1 : 60;   // minutes -> seconds
        QString result = QString::number(m.captured(1).toLongLong() * factor);
        if (!m.captured(2).isEmpty())
            result += QStringLiteral("–") + QString::number(m.captured(2).toLongLong() * factor);
        return result;
    }
    QString found;
    if (mode == QLatin1String("load"))
        found = find(num + QStringLiteral("\\s*kg"));
    else if (mode == QLatin1String("rpe"))
        found = find(QStringLiteral("RPE\\s*") + num);
    else if (mode == QLatin1String("percent"))
        found = find(num + QStringLiteral("\\s*%"));
    if (found.isEmpty())
        found = find(QStringLiteral("^\\s*") + num + QStringLiteral("\\s*$"));   // a bare number
    return found;
}

// `value` (any mode of field `key`) converted to `mode`: keeps the number when
// it fits ("8–10" -> "8–10 s", "45 s" -> "45"); "" when nothing fits
QString convertTo(const QString &key, const QString &value, const QString &mode)
{
    if (mode == kOther || ProgramEntry::modeOf(key, value) == mode)
        return value;
    const FieldMode *target = findMode(mode);
    if (!target || value.trimmed().isEmpty())
        return {};
    const QString from = ProgramEntry::modeOf(key, value);
    QString body = from == kOther ? extractFor(mode, value) : ProgramEntry::modeInput(value, from);
    body = normalized(body);
    if (mode != QLatin1String("reps") && body.endsWith(QLatin1Char('+')))
        body.chop(1);   // "20+" has no meaning for time
    const QString stored = target->prefix + body + target->suffix;
    return matches(*target, stored) ? stored : QString();
}

// A range left unfinished while typing ("8–", "30– s", "RPE 7–") saves as its
// first number
QString tidy(const QString &value)
{
    static const QRegularExpression open(QStringLiteral("(\\d)\\s*[-–]\\s*((?: s| kg|%)?)$"));
    QString result = value.trimmed();
    result.replace(open, QStringLiteral("\\1\\2"));
    return result;
}

} // namespace

QString ProgramEntry::modeOf(const QString &key, const QString &stored)
{
    const QStringList modes = modesFor(key);
    if (modes.isEmpty())
        return kOther;
    if (stored.trimmed().isEmpty())
        return modes.first();
    for (const QString &mode : modes)
        if (matches(*findMode(mode), stored))
            return mode;
    return kOther;
}

QString ProgramEntry::modeInput(const QString &stored, const QString &mode)
{
    const FieldMode *m = findMode(mode);
    QString body;
    return m && matches(*m, stored, &body) ? body : stored;
}

QString ProgramEntry::modeStored(const QString &input, const QString &mode)
{
    const FieldMode *m = findMode(mode);
    if (!m)
        return input;   // other: free text, as typed
    const QString body = normalized(input);
    return body.isEmpty() ? QString() : m->prefix + body + m->suffix;
}

QString ProgramEntry::mode(const QString &key) const
{
    if (key == QLatin1String("reps"))
        return repsMode;
    if (key == QLatin1String("load"))
        return loadMode;
    return {};
}

QString ProgramEntry::detectMode(const QString &key) const
{
    QStringList values{field(key)};
    for (auto it = weeks.cbegin(); it != weeks.cend(); ++it) {
        const QVariantMap change = it.value().toMap();
        if (change.contains(key))
            values.append(change.value(key).toString());
    }
    QString result;
    for (const QString &value : std::as_const(values)) {
        if (value.trimmed().isEmpty())
            continue;
        const QString m = modeOf(key, value);
        if (result.isEmpty())
            result = m;
        else if (m != result)
            return kOther;
    }
    return result.isEmpty() ? modeOf(key, {}) : result;
}

void ProgramEntry::setMode(const QString &key, const QString &mode)
{
    if (mode != kOther && !modesFor(key).contains(mode))
        return;
    setField(key, convertTo(key, field(key), mode));
    const QString base = field(key);
    for (auto it = weeks.begin(); it != weeks.end();) {
        QVariantMap change = it.value().toMap();
        if (change.contains(key)) {
            const QString value = convertTo(key, change.value(key).toString(), mode);
            // Same as the all-weeks value now: no longer a change for that week
            if (value == base)
                change.remove(key);
            else
                change.insert(key, value);
        }
        if (change.isEmpty()) {
            it = weeks.erase(it);
        } else {
            it.value() = change;
            ++it;
        }
    }
    if (key == QLatin1String("reps"))
        repsMode = mode;
    else if (key == QLatin1String("load"))
        loadMode = mode;
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
    e.repsMode = e.detectMode(QStringLiteral("reps"));
    e.loadMode = e.detectMode(QStringLiteral("load"));
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
    // The editor's choice when the draft has one, else worked out from the text
    const QString reps = str(map, "repsMode");
    e.repsMode = reps.isEmpty() ? e.detectMode(QStringLiteral("reps")) : reps;
    const QString load = str(map, "loadMode");
    e.loadMode = load.isEmpty() ? e.detectMode(QStringLiteral("load")) : load;
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
            {QStringLiteral("weeks"), weeks},
            {QStringLiteral("repsMode"), repsMode.isEmpty() ? detectMode(QStringLiteral("reps")) : repsMode},
            {QStringLiteral("loadMode"), loadMode.isEmpty() ? detectMode(QStringLiteral("load")) : loadMode}};
}

// No modes: the database only stores the reps and load text
QJsonObject ProgramEntry::toSaveJson() const
{
    QVariantMap savedWeeks = weeks;
    for (auto it = savedWeeks.begin(); it != savedWeeks.end(); ++it) {
        QVariantMap change = it.value().toMap();
        for (const QString key : {QStringLiteral("reps"), QStringLiteral("load")})
            if (change.contains(key))
                change.insert(key, tidy(change.value(key).toString()));
        it.value() = change;
    }
    return {{QStringLiteral("id"), uid},
            {QStringLiteral("exerciseId"), exerciseId},
            {QStringLiteral("sets"), sets},
            {QStringLiteral("reps"), tidy(reps)},
            {QStringLiteral("load"), tidy(load)},
            {QStringLiteral("rest"), rest},
            {QStringLiteral("notes"), notes},
            {QStringLiteral("weeks"), QJsonObject::fromVariantMap(savedWeeks)}};
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
