import Foundation
import CoreModels
import HealthKitClient
import Persistence

public enum PromptBuilder {
    static let planGenFraming: String = """
    You are {coachName}, {coachTagline}.
    You design adaptive workouts based on the user's profile and recent
    training history. You output a single JSON object matching the schema.
    Stream checkpoint markers as ⟦CHECKPOINT: <label>⟧ during reasoning so
    the UI can show progress.

    Final output must be a valid JSON object inside a ```json code block.
    Use this schema:

    {
      "weekStart": "<ISO8601 date>",
      "workouts": [{
        "id": "<short id>",
        "scheduledFor": "<ISO8601 date>",
        "title": "<2-4 words>",
        "subtitle": "<1 short phrase>",
        "workoutType": "Strength|HIIT|Mobility|Conditioning",
        "durationMin": <int>,
        "blocks": [{
          "id": "<short>",
          "label": "Warm-up|Main|Cooldown",
          "exercises": [{
            "id": "<unique within plan>",
            "exerciseID": "<catalog manifest id>",
            "name": "<display name>",
            "sets": [{"setNum": 1, "reps": 8, "load": "BW", "restSec": 60}]
          }]
        }],
        "why": "<1-2 sentences in your voice explaining today's focus>"
      }]
    }

    Generate one workout for today. Stream checkpoints as you reason.
    """

    static let strictRetrySuffix: String = """

    Important: respond with valid JSON only inside the ```json fence.
    Do not include any other prose after the JSON block.
    """

    /// Maximum number of exercises to embed in the system prompt to keep it compact.
    static let maxCatalogEntries = 50

    static func planGenSystemPrompt(
        coach: Coach,
        availableExercises: [(id: String, name: String, equipment: [String])] = [],
        strictRetry: Bool = false
    ) -> String {
        var s = planGenFraming
            .replacingOccurrences(of: "{coachName}", with: coach.displayName)
            .replacingOccurrences(of: "{coachTagline}", with: coach.tagline)

        if !availableExercises.isEmpty {
            let sample = Array(availableExercises.prefix(maxCatalogEntries))
            var catalog = "\n\nAvailable exercises (use these exact IDs for `exerciseID`):\n"
            for ex in sample {
                let equip = ex.equipment.isEmpty ? "body only" : ex.equipment.joined(separator: ", ")
                catalog += "- \(ex.id) | \(ex.name) | \(equip)\n"
            }
            catalog += "\nOnly use IDs from this list. Do not invent new exercise IDs."
            s += catalog
        }

        if strictRetry {
            s += strictRetrySuffix
        }
        return s
    }

    static func planGenUserMessage(profile: Profile, today: Date,
                                    summaries: SevenDayHealthSummary? = nil) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateStr = formatter.string(from: today)
        let goals = profile.goals.isEmpty ? "none" : profile.goals.joined(separator: ", ")
        let equipment = profile.equipment.isEmpty ? "none" : profile.equipment.joined(separator: ", ")
        var s = """
        Profile:
        - Name: \(profile.displayName)
        - Goals: \(goals)
        - Level: \(profile.level.rawValue)
        - Equipment available: \(equipment)
        - Sessions per week: \(profile.frequencyPerWeek)
        - Weekly target minutes: \(profile.weeklyTargetMinutes)

        Today: \(dateStr)
        """
        if let summaries, !summaries.isEmpty {
            s += "\n\n" + Self.healthSummaryBlock(summaries)
        }
        s += "\n\nGenerate today's workout."
        return s
    }

    static func healthSummaryBlock(_ s: SevenDayHealthSummary) -> String {
        var lines: [String] = ["7-DAY HEALTH SUMMARY (Apple Health):"]
        if let r = s.hr?.avgRestingHR { lines.append("- avg resting HR: \(r) bpm") }
        if let h = s.hr?.avgHRVSDNN   { lines.append("- avg HRV (SDNN): \(h) ms") }
        if let z = s.sleep?.avgSleepHours, z > 0 {
            lines.append(String(format: "- avg sleep: %.1f hrs", z))
        }
        if let a = s.activity {
            lines.append("- weekly active minutes: \(a.weeklyActiveMinutes) / \(a.targetActiveMinutes) target")
        }
        return lines.joined(separator: "\n")
    }

    static let adaptationFraming: String = """
    You are {coachName}, {coachTagline}.
    The user just completed today's session and gave feedback. Adapt
    TOMORROW's workout (the next scheduled session) — output ONE replacement
    workout with adjustments and a coach-voice rationale. Stream
    ⟦CHECKPOINT: <label>⟧ markers as you reason.

    Your output structure (after thinking):
    1. Up to 4 adjustment cards: {"id","label","detail"}, label ≤ 3 words,
       detail 6–10 words, each emitted on its own line as JSON inside a
       ```json fence labeled "adjustment".
    2. One full replacement workout matching the schedule date and the
       schema below — emitted in a ```json fence labeled "workout".
    3. One rationale line — 1 sentence, your voice — in a ```json fence
       labeled "rationale".

    Workout schema (same as plan-gen):

    {
      "id": "<short>",
      "scheduledFor": "<ISO8601 date>",
      "title": "<2-4 words>",
      "subtitle": "<1 phrase>",
      "workoutType": "Strength|HIIT|Mobility|Conditioning",
      "durationMin": <int>,
      "blocks": [{
        "id": "<short>",
        "label": "Warm-up|Main|Cooldown",
        "exercises": [{
          "id": "<unique>",
          "exerciseID": "<catalog id>",
          "name": "<display>",
          "sets": [{"setNum":1,"reps":8,"load":"BW","restSec":60}]
        }]
      }],
      "why": "<1-2 sentence coach voice>"
    }

    Adjustments must reflect what you actually did. Don't lie about the
    workout. Use only catalog IDs from the list below.
    """

    public static func adaptationSystemPrompt(
        coach: Coach,
        availableExercises: [(id: String, name: String, equipment: [String])] = [],
        strictRetry: Bool = false
    ) -> String {
        var s = adaptationFraming
            .replacingOccurrences(of: "{coachName}", with: coach.displayName)
            .replacingOccurrences(of: "{coachTagline}", with: coach.tagline)
        if !availableExercises.isEmpty {
            let sample = Array(availableExercises.prefix(maxCatalogEntries))
            var catalog = "\n\nAvailable exercises (use these exact IDs for `exerciseID`):\n"
            for ex in sample {
                let equip = ex.equipment.isEmpty ? "body only" : ex.equipment.joined(separator: ", ")
                catalog += "- \(ex.id) | \(ex.name) | \(equip)\n"
            }
            s += catalog
        }
        if strictRetry { s += strictRetrySuffix }
        return s
    }

    public static func adaptationUserMessage(
        nextWorkout: WorkoutEntity,
        justCompletedTitle: String,
        justCompletedDurationSec: Int,
        setLogs: [SetLogEntity],
        feedback: WorkoutFeedback,
        profile: Profile,
        summaries: SevenDayHealthSummary? = nil
    ) -> String {
        let nextJSON: String = {
            struct NextDTO: Encodable {
                let id: UUID
                let scheduledFor: Date
                let title: String
                let subtitle: String
                let workoutType: String
                let durationMin: Int
            }
            let dto = NextDTO(id: nextWorkout.id, scheduledFor: nextWorkout.scheduledFor,
                              title: nextWorkout.title, subtitle: nextWorkout.subtitle,
                              workoutType: nextWorkout.workoutType,
                              durationMin: nextWorkout.durationMin)
            return (try? JSONEncoder.pulse.encode(dto)).flatMap {
                String(data: $0, encoding: .utf8)
            } ?? "{}"
        }()
        let setLines = setLogs
            .sorted { ($0.exerciseID, $0.setNum) < ($1.exerciseID, $1.setNum) }
            .map { "- \($0.exerciseID) set \($0.setNum): \($0.reps) reps @ \($0.load), RPE \($0.rpe)" }
            .joined(separator: "\n")
        let exRatings = feedback.exerciseRatings
            .map { "  \($0.key): \($0.value.rawValue)" }
            .sorted()
            .joined(separator: "\n")
        let durMin = justCompletedDurationSec / 60
        let durSec = justCompletedDurationSec % 60
        var s = """
        SCHEDULED NEXT SESSION (to replace):
        \(nextJSON)

        JUST-COMPLETED SESSION:
        - workout: \(justCompletedTitle)
        - duration: \(durMin):\(String(format: "%02d", durSec))
        - sets logged:
        \(setLines)

        USER FEEDBACK:
        - rating: \(feedback.rating)/5
        - intensity: \(feedback.intensity)/5
        - mood: \(feedback.mood.rawValue)
        - tags: [\(feedback.tags.joined(separator: ", "))]
        - per-exercise:
        \(exRatings)
        - note: \(feedback.note ?? "")
        """
        if let summaries, !summaries.isEmpty {
            s += "\n\n" + Self.healthSummaryBlock(summaries)
        }
        s += """


        EQUIPMENT: \(profile.equipment.joined(separator: ", "))
        GOAL: \(profile.goals.joined(separator: ", "))
        LEVEL: \(profile.level.rawValue)
        """
        return s
    }
}
