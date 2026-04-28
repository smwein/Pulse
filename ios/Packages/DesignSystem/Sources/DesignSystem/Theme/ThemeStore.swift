import Foundation
import Observation
import CoreModels

@Observable
public final class ThemeStore {
    public private(set) var activeCoachID: String
    public private(set) var accent: AccentPalette

    public init(activeCoachID: String = "ace") {
        let resolved = Coach.byID(activeCoachID) ?? Coach.byID("ace")!
        self.activeCoachID = resolved.id
        self.accent = AccentPalette(hue: resolved.accentHue)
    }

    public func setActiveCoach(id: String) {
        guard let coach = Coach.byID(id) else { return }
        self.activeCoachID = coach.id
        self.accent = AccentPalette(hue: coach.accentHue)
    }
}
