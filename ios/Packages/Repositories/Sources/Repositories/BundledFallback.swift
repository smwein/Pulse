import Foundation
import CoreModels

public enum BundledFallback {
    public static func todayWorkout(profile: Profile, today: Date = Date()) -> WorkoutPlan {
        // Hand-authored 25-min mobility flow; conservative for any user.
        let warmup = WorkoutBlock(id: "wu", label: "Warm-up", exercises: [
            PlannedExercise(id: "wu1", exerciseID: "Cat_Stretch", name: "Cat Stretch",
                            sets: [PlannedSet(setNum: 1, reps: 8, load: "BW", restSec: 30)]),
            PlannedExercise(id: "wu2", exerciseID: "Standing_Hip_Circles",
                            name: "Standing Hip Circles",
                            sets: [PlannedSet(setNum: 1, reps: 6, load: "BW", restSec: 30)]),
        ])
        let main = WorkoutBlock(id: "main", label: "Main", exercises: [
            PlannedExercise(id: "m1", exerciseID: "Butt_Lift_Bridge", name: "Butt Lift (Bridge)",
                            sets: [
                                PlannedSet(setNum: 1, reps: 10, load: "BW", restSec: 45),
                                PlannedSet(setNum: 2, reps: 10, load: "BW", restSec: 45),
                                PlannedSet(setNum: 3, reps: 10, load: "BW", restSec: 45),
                            ]),
            PlannedExercise(id: "m2", exerciseID: "Dead_Bug", name: "Dead Bug",
                            sets: [
                                PlannedSet(setNum: 1, reps: 8, load: "BW", restSec: 45),
                                PlannedSet(setNum: 2, reps: 8, load: "BW", restSec: 45),
                            ]),
        ])
        let cooldown = WorkoutBlock(id: "cd", label: "Cooldown", exercises: [
            PlannedExercise(id: "cd1", exerciseID: "All_Fours_Quad_Stretch",
                            name: "All Fours Quad Stretch",
                            sets: [PlannedSet(setNum: 1, reps: 6, load: "BW", restSec: 30)]),
        ])
        let pw = PlannedWorkout(id: "fallback-\(Int(today.timeIntervalSince1970))",
            scheduledFor: today,
            title: "Steady reset",
            subtitle: "Mobility flow",
            workoutType: "Mobility", durationMin: 25,
            blocks: [warmup, main, cooldown],
            why: "Keeping things steady today.")
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let weekStart = iso.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return WorkoutPlan(weekStart: weekStart, workouts: [pw])
    }

    /// All exercise IDs the fallback uses. Tests assert these exist in the catalog manifest fixture.
    public static let exerciseIDs: [String] = [
        "Cat_Stretch", "Standing_Hip_Circles", "Butt_Lift_Bridge",
        "Dead_Bug", "All_Fours_Quad_Stretch"
    ]
}
