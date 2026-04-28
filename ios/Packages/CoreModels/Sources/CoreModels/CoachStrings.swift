import Foundation

public enum CoachStrings {
    public static let onboardingWelcome: [String: String] = [
        "ace":  "Hey, I'm Ace. Let's build something.",
        "rex":  "Welcome — Rex. We're going to take this seriously.",
        "vera": "Vera here. Tell me where you want to be in 12 weeks.",
        "mira": "I'm Mira. We'll start where you are.",
    ]

    public static let planGenHeader: [String: String] = [
        "ace":  "Putting your day together",
        "rex":  "Building today's session",
        "vera": "Designing this for you",
        "mira": "Shaping today",
    ]

    public static let homeGreeting: [String: String] = [
        "ace":  "Hey",
        "rex":  "Morning",
        "vera": "Welcome back",
        "mira": "Hi",
    ]

    public static func onboardingWelcome(for coachID: String) -> String {
        onboardingWelcome[coachID] ?? onboardingWelcome["ace"]!
    }

    public static func planGenHeader(for coachID: String) -> String {
        planGenHeader[coachID] ?? planGenHeader["ace"]!
    }

    public static func homeGreeting(for coachID: String) -> String {
        homeGreeting[coachID] ?? homeGreeting["ace"]!
    }
}
