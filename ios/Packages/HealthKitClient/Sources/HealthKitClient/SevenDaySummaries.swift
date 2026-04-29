import Foundation

public struct SevenDayActivitySummary: Codable, Sendable {
    public var weeklyActiveMinutes: Int
    public var targetActiveMinutes: Int

    public init(weeklyActiveMinutes: Int, targetActiveMinutes: Int) {
        self.weeklyActiveMinutes = weeklyActiveMinutes
        self.targetActiveMinutes = targetActiveMinutes
    }
}

public struct SevenDayHRSummary: Codable, Sendable {
    public var avgRestingHR: Int?
    public var avgHRVSDNN: Int?

    public init(avgRestingHR: Int?, avgHRVSDNN: Int?) {
        self.avgRestingHR = avgRestingHR
        self.avgHRVSDNN = avgHRVSDNN
    }
}

public struct SevenDaySleepSummary: Codable, Sendable {
    /// Average sleep hours per night (asleep + REM + deep + core).
    public var avgSleepHours: Double?

    public init(avgSleepHours: Double?) {
        self.avgSleepHours = avgSleepHours
    }
}

public struct SevenDayHealthSummary: Codable, Sendable {
    public var activity: SevenDayActivitySummary?
    public var hr: SevenDayHRSummary?
    public var sleep: SevenDaySleepSummary?

    public init(activity: SevenDayActivitySummary?,
                hr: SevenDayHRSummary?,
                sleep: SevenDaySleepSummary?) {
        self.activity = activity
        self.hr = hr
        self.sleep = sleep
    }

    /// Returns true if every field is nil — used to omit the prompt block entirely.
    public var isEmpty: Bool {
        activity == nil && hr == nil && sleep == nil
    }
}
