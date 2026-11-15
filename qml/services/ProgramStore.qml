pragma Singleton
import QtQuick

// Programs and the exercise library.
//
// PHASE 0: in-memory mock with sample data. In Phase 2 this becomes a C++
// repository backed by the API (tables: exercises, programs, program_days,
// program_exercises). Screens only use the functions below, so they won't
// need to change.
//
// Data shapes
//   exercise: { id, name, muscle, equipment, instructions, videoUrl }
//   program:  { id, name, description, weeks, updatedAt (ms),
//               days: [ { id, name, exercises: [ entry ] } ] }
//   entry:    { uid, exerciseId, sets, reps, load, rest, notes, weeks }
//             sets/reps/load/rest/notes are strings and apply to every week.
//             weeks holds per-week changes: { "4": { sets: "3", load: "60%" } }
//             Only the keys in weeklyKeys can change per week.
//
// How many clients follow a program comes from ClientStore.
QtObject {
    id: store

    // Stored values. Translate at display time when localization arrives.
    readonly property var muscleGroups: [
        "Chest", "Back", "Legs", "Glutes", "Shoulders", "Arms", "Core", "Full body", "Cardio"
    ]
    readonly property var equipmentTypes: [
        "Bodyweight", "Dumbbells", "Barbell", "Kettlebell", "Machine", "Cable", "Bands", "Other"
    ]

    // Fields of an exercise entry that can differ from week to week
    readonly property var weeklyKeys: ["sets", "reps", "load"]

    property var exercises: []
    property var programs: []

    // ---- exercises ----------------------------------------------------------

    function exerciseById(id) {
        return exercises.find(e => e.id === id) || null
    }

    // muscle: "" for all groups
    function searchExercises(query, muscle) {
        const q = (query || "").trim().toLowerCase()
        return exercises
            .filter(e => (!muscle || e.muscle === muscle)
                      && (!q || e.name.toLowerCase().includes(q)
                             || e.equipment.toLowerCase().includes(q)))
            .sort((a, b) => a.name.localeCompare(b.name))
    }

    function countByMuscle(muscle) {
        return muscle ? exercises.filter(e => e.muscle === muscle).length : exercises.length
    }

    function isExerciseNameTaken(name, exceptId) {
        const n = name.trim().toLowerCase()
        return exercises.some(e => e.id !== exceptId && e.name.toLowerCase() === n)
    }

    // Returns the exercise id
    function saveExercise(exercise) {
        const clean = {
            id: exercise.id || _nextId(),
            name: exercise.name.trim(),
            muscle: exercise.muscle,
            equipment: exercise.equipment,
            instructions: (exercise.instructions || "").trim(),
            videoUrl: (exercise.videoUrl || "").trim()
        }
        const list = exercises.filter(e => e.id !== clean.id)
        list.push(clean)
        exercises = list
        return clean.id
    }

    function deleteExercise(id) {
        if (usageCount(id) > 0)
            return false
        exercises = exercises.filter(e => e.id !== id)
        return true
    }

    // Number of programs that use the exercise
    function usageCount(exerciseId) {
        return programs.filter(p => p.days.some(d => d.exercises.some(x => x.exerciseId === exerciseId))).length
    }

    // ---- programs -----------------------------------------------------------

    function searchPrograms(query) {
        const q = (query || "").trim().toLowerCase()
        return programs
            .filter(p => !q || p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q))
            .sort((a, b) => b.updatedAt - a.updatedAt)
    }

    function exerciseCount(program) {
        return program.days.reduce((sum, d) => sum + d.exercises.length, 0)
    }

    // Deep copy for editing; changes reach the store only through saveProgram()
    function cloneProgram(id) {
        const p = programs.find(p => p.id === id)
        return p ? JSON.parse(JSON.stringify(p)) : newProgramDraft()
    }

    function newProgramDraft() {
        return {
            id: 0,
            name: "",
            description: "",
            weeks: "4",
            updatedAt: Date.now(),
            days: [ newDay(1) ]
        }
    }

    function newDay(number) {
        return { id: _nextId(), name: qsTr("Day %1").arg(number), exercises: [] }
    }

    function newEntry(exerciseId) {
        return { uid: _nextId(), exerciseId: exerciseId, sets: "3", reps: "10", load: "", rest: "60", notes: "", weeks: {} }
    }

    // Copy of a day with fresh ids, for "Duplicate day"
    function duplicateDay(day) {
        const copy = JSON.parse(JSON.stringify(day))
        copy.id = _nextId()
        copy.name = qsTr("%1 (copy)").arg(day.name)
        copy.exercises.forEach(x => x.uid = _nextId())
        return copy
    }

    // Returns the program id
    function saveProgram(draft) {
        const program = JSON.parse(JSON.stringify(draft))
        program.id = program.id || _nextId()
        program.name = program.name.trim()
        program.description = program.description.trim()
        program.updatedAt = Date.now()
        // Drop week changes beyond the program length
        const count = weekCount(program)
        program.days.forEach(d => d.exercises.forEach(x => {
            Object.keys(x.weeks || {}).forEach(w => { if (Number(w) > count) delete x.weeks[w] })
        }))
        programs = programs.filter(p => p.id !== program.id).concat([program])
        return program.id
    }

    // ---- per-week values ----------------------------------------------------

    function weekCount(program) {
        return Math.max(1, Math.min(52, parseInt(program.weeks) || 1))
    }

    // Value of `key` for `week` (0 = the all-weeks value)
    function effective(entry, week, key) {
        const change = week > 0 && entry.weeks ? entry.weeks[week] : null
        if (change && change[key] !== undefined)
            return change[key]
        return entry[key] || ""
    }

    // Keys changed for `week`. Extra arguments are ignored; callers pass a
    // revision number so bindings re-evaluate after in-place edits.
    function changedKeys(entry, week) {
        const change = week > 0 && entry.weeks ? entry.weeks[week] : null
        return change ? Object.keys(change) : []
    }

    // Weeks in which this entry differs from its all-weeks values
    function entryChangedWeeks(entry) {
        return Object.keys(entry.weeks || {}).map(Number).sort((a, b) => a - b)
    }

    // Weeks in which anything in the program differs
    function programChangedWeeks(program) {
        const set = {}
        program.days.forEach(d => d.exercises.forEach(x => entryChangedWeeks(x).forEach(w => set[w] = true)))
        return Object.keys(set).map(Number).sort((a, b) => a - b)
    }

    // Changes `entry` in place. Setting the all-weeks value removes the change.
    function setWeekValue(entry, week, key, value) {
        if (!entry.weeks)
            entry.weeks = {}
        const change = entry.weeks[week] || {}
        if (value === entry[key])
            delete change[key]
        else
            change[key] = value
        if (Object.keys(change).length === 0)
            delete entry.weeks[week]
        else
            entry.weeks[week] = change
    }

    // ---- read-only display helpers (client app) ----------------------------

    // Program week to show for an assignment week. An assignment extended past
    // the program's length keeps repeating the program's last week.
    function programWeekFor(program, assignmentWeek) {
        return Math.max(1, Math.min(assignmentWeek, weekCount(program)))
    }

    // "4 × 6–8", or just "30 min" for a single set
    function prescriptionText(entry, week) {
        const sets = effective(entry, week, "sets")
        const reps = effective(entry, week, "reps")
        if (!sets || sets === "1")
            return reps
        return reps ? qsTr("%1 × %2").arg(sets).arg(reps) : qsTr("%1 sets").arg(sets)
    }

    // "90 s", "2 min", "2 min 30 s"; "" for no rest
    function restText(seconds) {
        const s = parseInt(seconds) || 0
        if (s <= 0)
            return ""
        if (s < 120 && s % 60 !== 0)
            return qsTr("%1 s").arg(s)
        const m = Math.floor(s / 60)
        const r = s % 60
        return r === 0 ? qsTr("%1 min").arg(m) : qsTr("%1 min %2 s").arg(m).arg(r)
    }

    function deleteProgram(id) {
        programs = programs.filter(p => p.id !== id)
    }

    // "Edited today", "Edited 3 days ago", ...
    function editedLabel(ms) {
        const days = Math.floor((Date.now() - ms) / 86400000)
        if (days <= 0)
            return qsTr("Edited today")
        if (days === 1)
            return qsTr("Edited yesterday")
        if (days < 30)
            return qsTr("Edited %1 days ago").arg(days)
        return qsTr("Edited %1").arg(Qt.formatDate(new Date(ms), "d MMM yyyy"))
    }

    // ---- internals ----------------------------------------------------------

    property int _lastId: 1000
    function _nextId() {
        _lastId += 1
        return _lastId
    }

    Component.onCompleted: {
        const ex = (id, name, muscle, equipment, instructions) =>
            ({ id: id, name: name, muscle: muscle, equipment: equipment, instructions: instructions, videoUrl: "" })

        exercises = [
            ex(1, "Barbell bench press", "Chest", "Barbell", "Lie on the bench, lower the bar to mid-chest, press back up with elbows at about 45°."),
            ex(2, "Push-up", "Chest", "Bodyweight", "Hands under shoulders, body in a straight line, lower the chest to just above the floor."),
            ex(3, "Incline dumbbell press", "Chest", "Dumbbells", "Bench at 30°, press the dumbbells up and slightly together."),
            ex(4, "Cable fly", "Chest", "Cable", "Slight bend in the elbows, bring the handles together in a wide arc."),
            ex(5, "Pull-up", "Back", "Bodyweight", "Start from a dead hang, pull until the chin clears the bar, lower with control."),
            ex(6, "Barbell row", "Back", "Barbell", "Hinge to about 45°, pull the bar to the lower ribs, keep the back neutral."),
            ex(7, "Lat pulldown", "Back", "Machine", "Pull the bar to the upper chest, leading with the elbows."),
            ex(8, "Seated cable row", "Back", "Cable", "Sit tall, pull the handle to the stomach, squeeze the shoulder blades."),
            ex(9, "One-arm dumbbell row", "Back", "Dumbbells", "Support on a bench, row the dumbbell towards the hip."),
            ex(10, "Back squat", "Legs", "Barbell", "Bar on upper back, sit down between the hips to at least parallel, drive up."),
            ex(11, "Goblet squat", "Legs", "Kettlebell", "Hold the bell at the chest, squat deep with an upright torso."),
            ex(12, "Romanian deadlift", "Legs", "Barbell", "Soft knees, push the hips back until a hamstring stretch, then stand up."),
            ex(13, "Walking lunge", "Legs", "Dumbbells", "Long step forward, back knee towards the floor, alternate legs."),
            ex(14, "Leg press", "Legs", "Machine", "Feet shoulder-width, lower until knees reach about 90°, press without locking out."),
            ex(15, "Bulgarian split squat", "Legs", "Dumbbells", "Rear foot on a bench, lower straight down on the front leg."),
            ex(16, "Hip thrust", "Glutes", "Barbell", "Upper back on a bench, drive the hips up and squeeze the glutes at the top."),
            ex(17, "Glute bridge", "Glutes", "Bodyweight", "Lying on your back, push through the heels to lift the hips."),
            ex(18, "Kettlebell swing", "Glutes", "Kettlebell", "Hinge and snap the hips forward to swing the bell to chest height."),
            ex(19, "Overhead press", "Shoulders", "Barbell", "Press the bar from the shoulders to overhead, keep the ribs down."),
            ex(20, "Lateral raise", "Shoulders", "Dumbbells", "Raise the dumbbells out to the side up to shoulder height."),
            ex(21, "Face pull", "Shoulders", "Cable", "Rope at face height, pull towards the eyes with elbows high."),
            ex(22, "Dumbbell biceps curl", "Arms", "Dumbbells", "Elbows by your sides, curl up without swinging."),
            ex(23, "Hammer curl", "Arms", "Dumbbells", "Neutral grip, curl with the thumbs pointing up."),
            ex(24, "Triceps rope pushdown", "Arms", "Cable", "Elbows fixed, push the rope down and spread it at the bottom."),
            ex(25, "Plank", "Core", "Bodyweight", "Forearms on the floor, body in a straight line, breathe steadily."),
            ex(26, "Dead bug", "Core", "Bodyweight", "Lower back pressed to the floor, extend opposite arm and leg slowly."),
            ex(27, "Pallof press", "Core", "Cable", "Stand side-on to the cable, press the handle out and resist the rotation."),
            ex(28, "Hanging knee raise", "Core", "Bodyweight", "Hang from a bar, bring the knees up towards the chest without swinging."),
            ex(29, "Deadlift", "Full body", "Barbell", "Bar over mid-foot, brace, push the floor away and stand tall."),
            ex(30, "Burpee", "Full body", "Bodyweight", "Squat, jump the feet back, chest to floor, jump back in and up."),
            ex(31, "Dumbbell thruster", "Full body", "Dumbbells", "Front squat straight into an overhead press in one movement."),
            ex(32, "Rowing machine", "Cardio", "Machine", "Legs, then hips, then arms; reverse on the way back."),
            ex(33, "Air bike", "Cardio", "Machine", "Push and pull the handles while pedalling at a steady or interval pace."),
            ex(34, "Jump rope", "Cardio", "Other", "Small, quick jumps on the balls of the feet, wrists turning the rope.")
        ]

        const e = (exerciseId, sets, reps, rest, load, notes, weeks) =>
            ({ uid: _nextId(), exerciseId: exerciseId, sets: sets, reps: reps, rest: rest,
               load: load || "", notes: notes || "", weeks: weeks || {} })
        const daysAgo = n => Date.now() - n * 86400000
        const deload = { sets: "3", reps: "5", load: "Deload · 60%" }
        const test = { sets: "3", reps: "3", load: "RPE 9 · test week" }

        programs = [
            {
                id: 101, name: "Strength foundations", weeks: "8", updatedAt: daysAgo(2),
                description: "Three full sessions a week built around the main lifts. For clients with some gym experience.",
                days: [
                    { id: 201, name: "Day 1 · Lower body", exercises: [
                        e(10, "4", "6–8", "120", "RPE 7", "Add 2.5 kg when all sets hit 8", { "4": deload, "8": test }),
                        e(12, "3", "8–10", "90", "RPE 7", "", { "4": { sets: "2", load: "Deload · 60%" } }),
                        e(13, "3", "10 per leg", "60", "2 × 12 kg"),
                        e(25, "3", "45 s", "45", "", "", { "5": { reps: "60 s" }, "6": { reps: "60 s" }, "7": { reps: "75 s" }, "8": { reps: "75 s" } }) ] },
                    { id: 202, name: "Day 2 · Upper body", exercises: [
                        e(1, "4", "6–8", "120", "RPE 7", "", { "4": deload, "8": test }),
                        e(6, "4", "8", "90", "RPE 7"),
                        e(19, "3", "8", "90", "RPE 7", "", { "4": { sets: "2", load: "Deload · 60%" } }),
                        e(21, "3", "12–15", "45", "Light cable") ] },
                    { id: 203, name: "Day 3 · Full body", exercises: [
                        e(29, "3", "5", "150", "RPE 7", "Stop 2 reps before failure", { "4": { sets: "2", load: "Deload · 60%" } }),
                        e(5, "3", "Max", "120", "Bodyweight"),
                        e(11, "3", "10", "60", "16 kg"),
                        e(27, "3", "10 per side", "45") ] }
                ]
            },
            {
                id: 102, name: "Home training, no equipment", weeks: "6", updatedAt: daysAgo(9),
                description: "Bodyweight sessions for clients who train at home or while travelling.",
                days: [
                    { id: 204, name: "Day 1 · Push and legs", exercises: [
                        e(2, "4", "10–15", "60", "", "", { "4": { reps: "15–20" }, "5": { reps: "15–20" }, "6": { reps: "20+" } }),
                        e(17, "3", "15", "45"),
                        e(30, "3", "10", "60", "", "", { "5": { sets: "4" }, "6": { sets: "4" } }) ] },
                    { id: 205, name: "Day 2 · Core and conditioning", exercises: [
                        e(26, "3", "8 per side", "45"),
                        e(25, "3", "40 s", "30"),
                        e(34, "5", "1 min", "30") ] }
                ]
            },
            {
                id: 103, name: "Fat loss conditioning", weeks: "12", updatedAt: daysAgo(20),
                description: "Circuit-style sessions with short rests to keep the heart rate up.",
                days: [
                    { id: 206, name: "Day 1 · Circuit A", exercises: [
                        e(18, "4", "15", "30", "16 kg"),
                        e(31, "4", "10", "30", "2 × 8 kg"),
                        e(32, "4", "250 m", "60", "Hard pace") ] },
                    { id: 207, name: "Day 2 · Circuit B", exercises: [
                        e(11, "4", "12", "30", "16 kg"),
                        e(9, "4", "10 per arm", "30", "14 kg"),
                        e(33, "6", "20 s hard", "40") ] },
                    { id: 208, name: "Day 3 · Steady cardio", exercises: [
                        e(32, "1", "30 min", "0", "Easy pace", "Able to talk the whole time") ] }
                ]
            },
            {
                id: 104, name: "Glute and core focus", weeks: "4", updatedAt: daysAgo(1),
                description: "Draft: lower-body accessory block.",
                days: [
                    { id: 209, name: "Day 1", exercises: [
                        e(16, "4", "10", "90", "40 kg"),
                        e(15, "3", "10 per leg", "60", "2 × 10 kg") ] }
                ]
            }
        ]
    }
}
