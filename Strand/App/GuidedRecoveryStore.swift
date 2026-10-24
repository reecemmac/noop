import Foundation
import StrandAnalytics

/// Local iPhone measurement metadata. This opt-in side-store does not change the shared workout schema
/// or the cross-platform backup whitelist. Raw readings let future versions audit the displayed values.
struct GuidedRecoveryRecord: Codable, Equatable, Identifiable {
    enum Posture: String, Codable, CaseIterable { case sitting, standing, walking }
    enum Status: String, Codable { case measuring, completed, interrupted }
    let workoutStart: Int
    let workoutEnd: Int
    let sport: String
    let deviceId: String
    let posture: Posture
    var samples: [TimedHeartRateRecovery.Sample]
    var observedThrough: Int
    var status: Status = .measuring

    var id: String { "\(workoutStart):\(sport)" }
    func reading(at offset: Int) -> Int? {
        TimedHeartRateRecovery.reading(samples: samples, target: workoutEnd + offset,
                                       observedThrough: observedThrough)
    }
    func drop(at offset: Int) -> Int? {
        guard let end = reading(at: 0), let after = reading(at: offset) else { return nil }
        return end - after
    }

    mutating func append(bpm: Int, timestamp: Int) {
        guard status == .measuring, (30...220).contains(bpm),
              timestamp > workoutEnd, timestamp <= workoutEnd + 120,
              !samples.contains(where: { $0.ts == timestamp }) else { return }
        samples.append(.init(ts: timestamp, bpm: bpm))
    }

    mutating func advance(to timestamp: Int, activeDeviceId: String, workoutActive: Bool) {
        guard status == .measuring else { return }
        guard timestamp >= observedThrough, timestamp - observedThrough <= 5,
              deviceId == activeDeviceId, !workoutActive else {
            status = .interrupted
            return
        }
        observedThrough = min(timestamp, workoutEnd + TimedHeartRateRecovery.duration)
        if timestamp >= workoutEnd + TimedHeartRateRecovery.duration { status = .completed }
    }
}

enum GuidedRecoveryStore {
    private static let indexKey = "noop.guidedRecovery.index"
    private static func key(_ id: String) -> String { "noop.guidedRecovery.record.\(id)" }

    @discardableResult
    static func save(_ record: GuidedRecoveryRecord, defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        defaults.set(data, forKey: key(record.id))
        var ids = defaults.stringArray(forKey: indexKey) ?? []
        if !ids.contains(record.id) { ids.append(record.id); defaults.set(ids, forKey: indexKey) }
        return true
    }

    static func load(workoutStart: Int, sport: String,
                     defaults: UserDefaults = .standard) -> GuidedRecoveryRecord? {
        guard let data = defaults.data(forKey: key("\(workoutStart):\(sport)")),
              var record = try? JSONDecoder().decode(GuidedRecoveryRecord.self, from: data),
              record.workoutStart == workoutStart, record.sport == sport,
              record.workoutEnd > record.workoutStart else { return nil }
        // A process restart cannot assert continuous observation. Preserve collected samples, mark partial.
        if record.status == .measuring { record.status = .interrupted }
        return record
    }

    static func comparable(to record: GuidedRecoveryRecord,
                           defaults: UserDefaults = .standard) -> [GuidedRecoveryRecord] {
        (defaults.stringArray(forKey: indexKey) ?? []).compactMap { id -> GuidedRecoveryRecord? in
            guard let data = defaults.data(forKey: key(id)),
                  let previous = try? JSONDecoder().decode(GuidedRecoveryRecord.self, from: data),
                  previous.status == .completed, previous.sport == record.sport,
                  previous.posture == record.posture, previous.deviceId == record.deviceId,
                  previous.workoutEnd < record.workoutEnd else { return nil }
            return previous
        }.sorted { $0.workoutEnd > $1.workoutEnd }
    }

    /// Follow a successfully edited workout's natural key without moving any sensor timestamps.
    static func move(workoutStart: Int, sport: String, toStart: Int, toSport: String,
                     defaults: UserDefaults = .standard) {
        guard workoutStart != toStart || sport != toSport,
              let old = load(workoutStart: workoutStart, sport: sport, defaults: defaults) else { return }
        let moved = GuidedRecoveryRecord(workoutStart: toStart, workoutEnd: old.workoutEnd,
                                         sport: toSport, deviceId: old.deviceId, posture: old.posture,
                                         samples: old.samples, observedThrough: old.observedThrough,
                                         status: old.status)
        if save(moved, defaults: defaults) { remove(workoutStart: workoutStart, sport: sport, defaults: defaults) }
    }

    static func remove(workoutStart: Int, sport: String, defaults: UserDefaults = .standard) {
        let id = "\(workoutStart):\(sport)"
        defaults.removeObject(forKey: key(id))
        defaults.set((defaults.stringArray(forKey: indexKey) ?? []).filter { $0 != id }, forKey: indexKey)
    }
}
