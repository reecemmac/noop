import Foundation

/// Readings for an explicitly timed recovery protocol, separate from retrospective workout HRR.
/// Kotlin twin: `TimedHeartRateRecovery.kt`. No clinical thresholds or interpolation are applied.
public enum TimedHeartRateRecovery {
    public struct Sample: Codable, Equatable, Sendable {
        public let ts: Int
        public let bpm: Int
        public init(ts: Int, bpm: Int) { self.ts = ts; self.bpm = bpm }
    }

    public static let checkpoints = [0, 30, 60, 90, 120]
    public static let duration = 120

    /// Median of at least three distinct seconds in the five seconds ending at the target.
    /// A trailing window makes the final reading available at 120 seconds, without waiting longer.
    public static func reading(samples: [Sample], target: Int, observedThrough: Int) -> Int? {
        guard observedThrough >= target else { return nil }
        var seconds = Set<Int>()
        let values = samples.sorted { $0.ts == $1.ts ? $0.bpm < $1.bpm : $0.ts < $1.ts }
            .filter { $0.ts >= target - 4 && $0.ts <= target && (30...220).contains($0.bpm) }
            .filter { seconds.insert($0.ts).inserted }.map(\.bpm)
        guard values.count >= 3 else { return nil }
        return median(values)
    }

    /// A personal baseline needs three previous comparable sessions; caller supplies newest first.
    public static func baseline(_ drops: [Int?]) -> Int? {
        let values = Array(drops.compactMap { $0 }.prefix(10))
        return values.count >= 3 ? median(values) : nil
    }

    private static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted(), middle = values.count / 2
        return values.count.isMultiple(of: 2)
            ? Int((Double(sorted[middle - 1] + sorted[middle]) / 2).rounded()) : sorted[middle]
    }
}
