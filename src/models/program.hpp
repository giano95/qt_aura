// Programs and exercises, as QML sees them (value types):
//   exercise:  { id, name, muscle, equipment, instructions, videoUrl, builtIn }
//   program:   { id, name, description, weeks, updatedAt (ms), days: [ programDay ] }
//   programDay:   { id, name, exercises: [ programEntry ] }
//   programEntry: { uid, exerciseId, sets, reps, load, rest, notes, weeks }
//                 sets/reps/load/rest/notes apply to every week; weeks holds
//                 per-week changes of sets/reps/load: { "4": { "sets": "3" } }
//
// The program editor works on a plain JS copy of a program (a "draft", same
// field names, weeks as text). fromVariant() reads either form.
#pragma once

#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

struct Exercise
{
    Q_GADGET
    QML_VALUE_TYPE(exercise)

    Q_PROPERTY(QString id MEMBER id FINAL)
    Q_PROPERTY(QString name MEMBER name FINAL)
    Q_PROPERTY(QString muscle MEMBER muscle FINAL)
    Q_PROPERTY(QString equipment MEMBER equipment FINAL)
    Q_PROPERTY(QString instructions MEMBER instructions FINAL)
    Q_PROPERTY(QString videoUrl MEMBER videoUrl FINAL)
    // From the built-in library: read-only, shared by every coach
    Q_PROPERTY(bool builtIn MEMBER builtIn FINAL)

public:
    QString id;
    QString name;
    QString muscle;
    QString equipment;
    QString instructions;
    QString videoUrl;
    bool builtIn = false;

    static Exercise fromJson(const QJsonObject &row);
    friend bool operator==(const Exercise &, const Exercise &) = default;
};

struct ProgramEntry
{
    Q_GADGET
    QML_VALUE_TYPE(programEntry)

    Q_PROPERTY(QString uid MEMBER uid FINAL)
    Q_PROPERTY(QString exerciseId MEMBER exerciseId FINAL)
    Q_PROPERTY(QString sets MEMBER sets FINAL)
    Q_PROPERTY(QString reps MEMBER reps FINAL)
    Q_PROPERTY(QString load MEMBER load FINAL)
    Q_PROPERTY(QString rest MEMBER rest FINAL)
    Q_PROPERTY(QString notes MEMBER notes FINAL)
    Q_PROPERTY(QVariantMap weeks MEMBER weeks FINAL)
    Q_PROPERTY(QString repsMode MEMBER repsMode FINAL)
    Q_PROPERTY(QString loadMode MEMBER loadMode FINAL)

public:
    QString uid;
    QString exerciseId;
    QString sets;
    QString reps;
    QString load;
    QString rest;
    QString notes;
    QVariantMap weeks;
    // How the editor shows `reps` and `load`. Editor-only: worked out from the
    // stored text, never saved, so the database keeps the same plain text.
    //   reps: "reps" (10, 8–10, 20+), "time" (45 s, 30–45 s), "other"
    //   load: "load" (80 kg, 82.5 kg), "rpe" (RPE 8, RPE 7–8), "percent" (75%), "other"
    QString repsMode;
    QString loadMode;

    // Fields that can differ from week to week
    static const QStringList &weeklyKeys();

    // ---- field modes ("other" = free text) ----
    // Mode a stored text of field `key` fits ("" counts as the field's first mode)
    static QString modeOf(const QString &key, const QString &stored);
    // Stored text -> what the field shows in `mode`: the number part ("45 s" -> "45")
    static QString modeInput(const QString &stored, const QString &mode);
    // What the coach typed in `mode` -> stored text ("8-10" -> "8–10", "8" -> "RPE 8")
    static QString modeStored(const QString &input, const QString &mode);
    QString mode(const QString &key) const;
    // The mode of the all-weeks value; "other" if a week's value doesn't fit it
    QString detectMode(const QString &key) const;
    // Switches field `key` to `mode`, converting the all-weeks and per-week values
    void setMode(const QString &key, const QString &mode);

    QString field(const QString &key) const;
    void setField(const QString &key, const QString &value);
    // Value of `key` in `week` (0 = the all-weeks value)
    QString effective(int week, const QString &key) const;
    // Keys changed in `week`
    QStringList changedKeys(int week) const;
    // Weeks in which this entry differs from its all-weeks values, ascending
    QList<int> changedWeeks() const;
    // Setting the all-weeks value removes that week's change
    void setWeekValue(int week, const QString &key, const QString &value);
    // Drops changes for weeks after `weekCount`
    void dropWeeksAfter(int weekCount);

    static ProgramEntry fromJson(const QJsonObject &row);
    static ProgramEntry fromVariant(const QVariant &value);
    QVariantMap toVariantMap() const;
    QJsonObject toSaveJson() const;
    friend bool operator==(const ProgramEntry &, const ProgramEntry &) = default;
};

struct ProgramDay
{
    Q_GADGET
    QML_VALUE_TYPE(programDay)

    Q_PROPERTY(QString id MEMBER id FINAL)
    Q_PROPERTY(QString name MEMBER name FINAL)
    Q_PROPERTY(QList<ProgramEntry> exercises MEMBER exercises FINAL)

public:
    QString id;
    QString name;
    QList<ProgramEntry> exercises;

    static ProgramDay fromJson(const QJsonObject &row);
    static ProgramDay fromVariant(const QVariant &value);
    QVariantMap toVariantMap() const;
    QJsonObject toSaveJson() const;
    friend bool operator==(const ProgramDay &, const ProgramDay &) = default;
};

struct Program
{
    Q_GADGET
    QML_VALUE_TYPE(program)

    Q_PROPERTY(QString id MEMBER id FINAL)
    Q_PROPERTY(QString name MEMBER name FINAL)
    Q_PROPERTY(QString description MEMBER description FINAL)
    Q_PROPERTY(int weeks MEMBER weeks FINAL)
    Q_PROPERTY(double updatedAt MEMBER updatedAt FINAL)
    Q_PROPERTY(QList<ProgramDay> days MEMBER days FINAL)

public:
    QString id;
    QString name;
    QString description;
    int weeks = 1;
    double updatedAt = 0;
    QList<ProgramDay> days;

    static constexpr int maxWeeks = 52;
    // 1..52 from a number or the editor's text ("8", "", "abc")
    static int clampWeeks(const QVariant &weeks);

    int exerciseCount() const;
    // Weeks in which anything differs, ascending
    QList<int> changedWeeks() const;
    // Program week shown for an assignment week: past the end, the last week repeats
    int programWeekFor(int assignmentWeek) const;
    // Usage of an exercise anywhere in the program
    bool usesExercise(const QString &exerciseId) const;

    static Program fromJson(const QJsonObject &row);
    static Program fromVariant(const QVariant &value);
    // The editor's draft: plain JS object, weeks as text
    QVariantMap toVariantMap() const;
    // Body for the save_program SQL function
    QJsonObject toSaveJson() const;
    friend bool operator==(const Program &, const Program &) = default;
};
