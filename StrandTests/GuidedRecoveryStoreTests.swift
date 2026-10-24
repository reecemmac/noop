import XCTest
import StrandAnalytics
@testable import Strand

final class GuidedRecoveryStoreTests: XCTestCase {
    private func record(end: Int = 10_000, posture: GuidedRecoveryRecord.Posture = .sitting,
                        device: String = "strap", status: GuidedRecoveryRecord.Status = .completed) -> GuidedRecoveryRecord {
        let samples = [-4, -3, -2, -1, 0, 56, 57, 58, 59, 60, 116, 117, 118, 119, 120].map {
            TimedHeartRateRecovery.Sample(ts: end + $0, bpm: $0 <= 0 ? 170 : ($0 <= 60 ? 140 : 120))
        }
        return GuidedRecoveryRecord(workoutStart: end - 300, workoutEnd: end, sport: "Run",
                                    deviceId: device, posture: posture, samples: samples,
                                    observedThrough: end + 120, status: status)
    }

    func testRoundTripAndReadingDropsIncludingHeartRateRise() throws {
        let original = record()
        XCTAssertEqual(try JSONDecoder().decode(GuidedRecoveryRecord.self,
                       from: JSONEncoder().encode(original)), original)
        XCTAssertEqual(original.drop(at: 60), 30)
        XCTAssertEqual(original.drop(at: 120), 50)
        var rise = original
        rise.samples = rise.samples.map { .init(ts: $0.ts, bpm: $0.ts > rise.workoutEnd ? 180 : 170) }
        XCTAssertEqual(rise.drop(at: 60), -10)
    }

    func testAppendDoesNotRepeatHeldHRAndRejectsOutsideCaptureWindow() {
        var value = record(status: .measuring)
        value.samples = []
        value.append(bpm: 140, timestamp: value.workoutEnd + 60)
        value.append(bpm: 140, timestamp: value.workoutEnd + 60)
        value.append(bpm: 0, timestamp: value.workoutEnd + 61)
        value.append(bpm: 140, timestamp: value.workoutEnd + 121)
        XCTAssertEqual(value.samples.count, 1)
        XCTAssertNil(value.drop(at: 60))
        value.status = .interrupted
        value.append(bpm: 140, timestamp: value.workoutEnd + 62)
        XCTAssertEqual(value.samples.count, 1)
    }

    func testTimerCompletesExactlyAtTwoMinutesAndCannotResumeAfterCompletion() {
        var value = record(status: .measuring)
        value.observedThrough = value.workoutEnd
        for timestamp in value.workoutEnd..<(value.workoutEnd + 120) {
            value.advance(to: timestamp, activeDeviceId: "strap", workoutActive: false)
            XCTAssertEqual(value.status, .measuring)
        }
        value.advance(to: value.workoutEnd + 120, activeDeviceId: "strap", workoutActive: false)
        XCTAssertEqual(value.status, .completed)
        value.advance(to: value.workoutEnd + 121, activeDeviceId: "other", workoutActive: true)
        XCTAssertEqual(value.status, .completed)
    }

    func testClockDiscontinuitiesDeviceChangesAndNewWorkoutsInterrupt() {
        for (delta, device, active) in [(-1, "strap", false), (6, "strap", false),
                                         (1, "other", false), (1, "strap", true)] {
            var value = record(status: .measuring)
            value.observedThrough = value.workoutEnd
            value.advance(to: value.workoutEnd + delta, activeDeviceId: device, workoutActive: active)
            XCTAssertEqual(value.status, .interrupted)
        }
    }

    func testPersistenceFiltersComparisonsAndMarksInterruptedAfterRestart() throws {
        let name = "test.guidedRecovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let current = record(end: 20_000)
        let matching = record()
        for value in [matching, record(end: 11_000, posture: .walking),
                      record(end: 12_000, device: "other"), record(end: 13_000, status: .interrupted),
                      record(end: 14_000, status: .measuring), current, record(end: 30_000)] {
            XCTAssertTrue(GuidedRecoveryStore.save(value, defaults: defaults))
        }
        XCTAssertEqual(GuidedRecoveryStore.comparable(to: current, defaults: defaults), [matching])
        XCTAssertEqual(GuidedRecoveryStore.load(workoutStart: 13_700, sport: "Run", defaults: defaults)?.status,
                       .interrupted)
        GuidedRecoveryStore.remove(workoutStart: matching.workoutStart, sport: matching.sport, defaults: defaults)
        XCTAssertTrue(GuidedRecoveryStore.comparable(to: current, defaults: defaults).isEmpty)
    }

    func testWorkoutRekeyKeepsOriginalSensorTimestampsAndReadings() throws {
        let name = "test.guidedRecovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let original = record()
        GuidedRecoveryStore.save(original, defaults: defaults)
        GuidedRecoveryStore.move(workoutStart: original.workoutStart, sport: original.sport,
                                  toStart: original.workoutStart - 30, toSport: "Boxing", defaults: defaults)
        let moved = try XCTUnwrap(GuidedRecoveryStore.load(workoutStart: original.workoutStart - 30,
                                                          sport: "Boxing", defaults: defaults))
        XCTAssertEqual(moved.samples, original.samples)
        XCTAssertEqual(moved.workoutEnd, original.workoutEnd)
        XCTAssertEqual(moved.drop(at: 120), 50)
        XCTAssertNil(GuidedRecoveryStore.load(workoutStart: original.workoutStart,
                                              sport: original.sport, defaults: defaults))
    }
}
