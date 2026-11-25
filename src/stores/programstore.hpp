// Programs and the exercise library (QML singleton `ProgramStore`).
//
// Loads the signed-in user's data from Supabase (RLS decides what that is: a
// coach gets their programs plus the built-in and their own exercises; a client
// gets the programs assigned to them and the exercises those use). Changes show
// up locally right away, then go to the server; if the server refuses, the
// store reloads and emits errorOccurred.
//
// Bindings that call a function reading store data must pass `revision` as the
// last argument (see StoreBase), e.g.
// ProgramStore.searchExercises(text, muscle, ProgramStore.revision).
#pragma once

#include "program.hpp"
#include "storebase.hpp"

#include <QJSValue>
#include <QtQml/qqmlregistration.h>

class ProgramStore : public StoreBase
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Stored values. Translate at display time when localization arrives.
    Q_PROPERTY(QStringList muscleGroups READ muscleGroups CONSTANT FINAL)
    Q_PROPERTY(QStringList equipmentTypes READ equipmentTypes CONSTANT FINAL)
    Q_PROPERTY(QStringList weeklyKeys READ weeklyKeys CONSTANT FINAL)

    Q_PROPERTY(QList<Exercise> exercises READ exercises NOTIFY revisionChanged FINAL)
    Q_PROPERTY(QList<Program> programs READ programs NOTIFY revisionChanged FINAL)

public:
    explicit ProgramStore(QObject *parent = nullptr);

    QStringList muscleGroups() const;
    QStringList equipmentTypes() const;
    QStringList weeklyKeys() const { return ProgramEntry::weeklyKeys(); }
    QList<Exercise> exercises() const { return m_exercises; }
    QList<Program> programs() const { return m_programs; }

    // ---- exercises (pass `revision` last from bindings) ---------------------
    // The exercise, or null
    Q_INVOKABLE QVariant exerciseById(const QString &id, const QVariant &revision = {}) const;
    // muscle: "" for all groups; sorted by name
    Q_INVOKABLE QList<Exercise> searchExercises(const QString &query, const QString &muscle,
                                                const QVariant &revision = {}) const;
    Q_INVOKABLE int countByMuscle(const QString &muscle, const QVariant &revision = {}) const;
    Q_INVOKABLE bool isExerciseNameTaken(const QString &name, const QString &exceptId,
                                         const QVariant &revision = {}) const;
    // Number of programs that use the exercise
    Q_INVOKABLE int usageCount(const QString &exerciseId, const QVariant &revision = {}) const;

    // { id ("" = new), name, muscle, equipment, instructions, videoUrl }; returns the id
    Q_INVOKABLE QString saveExercise(const QVariantMap &exercise);
    // False if the exercise is used in a program or built-in
    Q_INVOKABLE bool deleteExercise(const QString &id);

    // ---- programs -------------------------------------------------------------
    // Newest first
    Q_INVOKABLE QList<Program> searchPrograms(const QString &query, const QVariant &revision = {}) const;
    // Editor drafts. These return real JS objects (not QVariantMap): the editor
    // changes them in place and shares them with its day cards and rows, which
    // only works if they all hold the same object. A QVariantMap stored in a
    // `property var` is copied on every assignment.
    Q_INVOKABLE QJSValue cloneProgram(const QString &id) const;
    Q_INVOKABLE QJSValue newProgramDraft() const;
    Q_INVOKABLE QJSValue newDay(int number) const;
    Q_INVOKABLE QJSValue newEntry(const QString &exerciseId) const;
    // Copy of a day with fresh ids, for "Duplicate day"
    Q_INVOKABLE QJSValue duplicateDay(const QVariant &day) const;

    // The same drafts as maps, for C++ and tests
    QVariantMap programDraft(const QString &id) const;
    QVariantMap emptyProgramDraft() const;
    QVariantMap dayDraft(int number) const;
    QVariantMap entryDraft(const QString &exerciseId) const;
    // Saves a draft; returns the program id
    Q_INVOKABLE QString saveProgram(const QVariant &draft);
    Q_INVOKABLE void deleteProgram(const QString &id);

    // ---- per-week values (programs or drafts; extra args are ignored) ---------
    Q_INVOKABLE int exerciseCount(const QVariant &program) const;
    Q_INVOKABLE int weekCount(const QVariant &program, const QVariant &revision = {}) const;
    Q_INVOKABLE QString effective(const QVariant &entry, int week, const QString &key) const;
    Q_INVOKABLE QStringList changedKeys(const QVariant &entry, int week, const QVariant &revision = {}) const;
    Q_INVOKABLE QList<int> entryChangedWeeks(const QVariant &entry, const QVariant &revision = {}) const;
    Q_INVOKABLE QList<int> programChangedWeeks(const QVariant &program, const QVariant &revision = {}) const;
    // Changes a draft entry (JS object) in place. Setting the all-weeks value removes the change.
    Q_INVOKABLE void setWeekValue(QJSValue entry, int week, const QString &key, const QString &value) const;

    // ---- field modes (editor only; the database keeps storing the text) ----
    // Modes: reps "reps" / "time" / "other"; load "load" / "rpe" / "percent" / "other"
    // Stored text -> what the field shows in `mode` (the number part)
    Q_INVOKABLE QString modeInput(const QString &stored, const QString &mode) const;
    // What the coach typed in `mode` -> stored text
    Q_INVOKABLE QString modeStored(const QString &input, const QString &mode) const;
    // Switches field `key` ("reps" or "load") of a draft entry (JS object) to
    // `mode`, converting its all-weeks and per-week values
    Q_INVOKABLE void setFieldMode(QJSValue entry, const QString &key, const QString &mode) const;

    // ---- display helpers ------------------------------------------------------
    Q_INVOKABLE int programWeekFor(const QVariant &program, int assignmentWeek) const;
    // "4 × 6–8", or just "30 min" for a single set
    Q_INVOKABLE QString prescriptionText(const QVariant &entry, int week) const;
    // "90 s", "2 min", "2 min 30 s"; "" for no rest
    Q_INVOKABLE QString restText(const QVariant &seconds) const;
    // "Edited today", "Edited 3 days ago", ...
    Q_INVOKABLE QString editedLabel(double ms) const;

protected:
    void load() override;
    bool clearData() override;
    QString errorText(const QString &code) const override;
    QList<Exercise> m_exercises;
    QList<Program> m_programs;
};
