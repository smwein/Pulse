import Foundation

public struct Coach: Identifiable, Hashable, Sendable {
    public let id: String           // "ace" | "rex" | "vera" | "mira"
    public let displayName: String
    public let tagline: String
    public let accentHue: Int       // 0–360, drives DesignSystem accent

    public init(id: String, displayName: String, tagline: String, accentHue: Int) {
        self.id = id
        self.displayName = displayName
        self.tagline = tagline
        self.accentHue = accentHue
    }

    public static let all: [Coach] = [
        Coach(id: "ace",  displayName: "Ace",  tagline: "the friend",   accentHue: 45),
        Coach(id: "rex",  displayName: "Rex",  tagline: "the athlete",  accentHue: 15),
        Coach(id: "vera", displayName: "Vera", tagline: "the analyst",  accentHue: 220),
        Coach(id: "mira", displayName: "Mira", tagline: "the mindful",  accentHue: 285),
    ]

    public static func byID(_ id: String) -> Coach? {
        all.first { $0.id == id }
    }
}
