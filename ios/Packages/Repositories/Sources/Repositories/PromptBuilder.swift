import Foundation
import CoreModels

enum PromptBuilder {
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

    static func planGenSystemPrompt(coach: Coach, strictRetry: Bool = false) -> String {
        var s = planGenFraming
            .replacingOccurrences(of: "{coachName}", with: coach.displayName)
            .replacingOccurrences(of: "{coachTagline}", with: coach.tagline)
        if strictRetry {
            s += strictRetrySuffix
        }
        return s
    }

    static func planGenUserMessage(profile: Profile, today: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateStr = formatter.string(from: today)
        let goals = profile.goals.joined(separator: ", ")
        let equipment = profile.equipment.joined(separator: ", ")
        return """
        Profile:
        - Name: \(profile.displayName)
        - Goals: \(goals)
        - Level: \(profile.level.rawValue)
        - Equipment available: \(equipment)
        - Sessions per week: \(profile.frequencyPerWeek)
        - Weekly target minutes: \(profile.weeklyTargetMinutes)

        Today: \(dateStr)

        Generate today's workout.
        """
    }
}
