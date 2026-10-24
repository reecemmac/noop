import XCTest
@testable import StrandAnalytics

final class TimedHeartRateRecoveryTests: XCTestCase {
    private let end = 10_000
    private func samples(_ values: [Int], endingAt target: Int) -> [TimedHeartRateRecovery.Sample] {
        values.enumerated().map { .init(ts: target - values.count + 1 + $0.offset, bpm: $0.element) }
    }

    func testCheckpointMediansRejectSpikesAndAreAvailableExactlyAtTarget() {
        for offset in TimedHeartRateRecovery.checkpoints {
            let target = end + offset
            let readings = samples([140, 141, 220, 139, 140], endingAt: target)
            XCTAssertNil(TimedHeartRateRecovery.reading(samples: readings, target: target,
                                                       observedThrough: target - 1))
            XCTAssertEqual(TimedHeartRateRecovery.reading(samples: readings.reversed(), target: target,
                                                         observedThrough: target), 140)
        }
    }

    func testMissingAndDuplicateSecondsCannotCreateCoverage() {
        let sample = TimedHeartRateRecovery.Sample(ts: end, bpm: 140)
        XCTAssertNil(TimedHeartRateRecovery.reading(samples: Array(repeating: sample, count: 20),
                                                   target: end, observedThrough: end))
        XCTAssertNil(TimedHeartRateRecovery.reading(samples: samples([140, 140, 140], endingAt: end - 5),
                                                   target: end, observedThrough: end))
        XCTAssertNil(TimedHeartRateRecovery.reading(samples: samples([0, 29, 221, 250], endingAt: end),
                                                   target: end, observedThrough: end))
    }

    func testWindowBoundariesAndEvenMedian() {
        let readings = samples([250, 100, 101, 102, 103, 200], endingAt: end + 1)
        XCTAssertEqual(TimedHeartRateRecovery.reading(samples: readings, target: end,
                                                     observedThrough: end), 102)
    }

    func testBaselineNeedsThreeReadingsAndUsesOnlyNewestTen() {
        XCTAssertNil(TimedHeartRateRecovery.baseline([nil, 10, 20]))
        XCTAssertEqual(TimedHeartRateRecovery.baseline([10, nil, 20, 30]), 20)
        XCTAssertEqual(TimedHeartRateRecovery.baseline([nil] + Array(repeating: 20, count: 10) + [200]), 20)
        XCTAssertEqual(TimedHeartRateRecovery.baseline([-3, -2, -2, -1]), -2)
        XCTAssertEqual(TimedHeartRateRecovery.baseline([-3, -2, -1, 0]), -2)
    }

    func testPinsCrossPlatformOracleForWindowsAndSignedBaselines() {
        var results: [String] = []
        for count in 0...8 {
            for offset in -6...2 {
                let samples = (0..<count).map { TimedHeartRateRecovery.Sample(ts: 100 + offset - $0, bpm: 139 + $0 % 4) }
                results.append(TimedHeartRateRecovery.reading(samples: samples, target: 100, observedThrough: 100).map(String.init) ?? "nil")
            }
        }
        for base in -5...5 {
            results.append(TimedHeartRateRecovery.baseline([base, base + 1, base + 2, base + 3]).map(String.init) ?? "nil")
        }
        XCTAssertEqual(results.joined(separator: ","), "nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,140,140,140,nil,nil,nil,nil,nil,nil,140,141,141,141,nil,nil,nil,nil,nil,140,141,140,141,141,nil,nil,nil,nil,140,141,140,140,141,nil,nil,nil,nil,140,141,140,140,141,nil,nil,nil,nil,140,141,140,140,141,-4,-3,-2,-1,1,2,3,4,5,6,7")
    }
}
