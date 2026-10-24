#if os(iOS)
import SwiftUI
import Charts
import StrandAnalytics
import StrandDesign

struct GuidedRecoveryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    let onClose: () -> Void

    private var remaining: Int {
        guard let record = model.guidedRecovery else { return 0 }
        return max(0, 120 - (record.observedThrough - record.workoutEnd))
    }

    var body: some View {
        ScrollView {
            if let record = model.guidedRecovery {
                VStack(alignment: .leading, spacing: NoopMetrics.sectionSpacing) {
                    Text("Post-workout recovery").font(StrandFont.title1)
                    if record.status == .measuring {
                        Text("Keep your chosen posture and stay on this screen. Missing HR stays unavailable.")
                            .font(StrandFont.body).foregroundStyle(StrandPalette.textSecondary)
                        Text("\(remaining) seconds remaining")
                            .font(StrandFont.number(32)).monospacedDigit()
                        Button("Stop measurement") { model.finishGuidedRecovery() }
                    } else {
                        if record.status == .completed {
                            Text("Measurement finished").font(StrandFont.body)
                        } else {
                            Text("Measurement interrupted — partial readings saved").font(StrandFont.body)
                        }
                        Button("Done") { model.closeGuidedRecovery(); onClose() }
                    }
                    GuidedRecoveryResults(record: record)
                }
                .screenPadding()
                .padding(.vertical, NoopMetrics.space6)
            }
        }
        .task {
            while !Task.isCancelled, model.guidedRecovery?.status == .measuring {
                model.tickGuidedRecovery()
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            }
        }
        .onChangeCompat(of: scenePhase) { phase in
            if phase != .active { model.finishGuidedRecovery() }
        }
        .onDisappear { model.closeGuidedRecovery() }
    }
}

struct GuidedRecoveryResults: View {
    let record: GuidedRecoveryRecord
    @State private var previous: [GuidedRecoveryRecord] = []

    private var postureLabel: String {
        switch record.posture {
        case .sitting: return String(localized: "Sitting")
        case .standing: return String(localized: "Standing")
        case .walking: return String(localized: "Walking")
        }
    }

    var body: some View {
        NoopCard(tint: StrandPalette.metricRose) {
            VStack(alignment: .leading, spacing: NoopMetrics.space4) {
                Text("Guided heart-rate recovery").font(StrandFont.headline)
                Text(postureLabel).font(StrandFont.footnote)
                if record.status == .interrupted {
                    Text("Measurement interrupted — partial readings saved")
                        .font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                }
                ForEach(TimedHeartRateRecovery.checkpoints, id: \.self) { offset in
                    HStack {
                        Text("\(offset) seconds")
                        Spacer()
                        if let reading = record.reading(at: offset) {
                            Text("\(reading) bpm").monospacedDigit()
                        } else { Text("–") }
                    }
                }
                Divider()
                recoveryLine("HRR1", offset: 60)
                recoveryLine("HRR2", offset: 120)
                Text("HRR is the fall from the finish reading. A dash means fewer than three recorded seconds near that checkpoint. These are descriptive measurements, not a medical fitness score.")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                Text("Personal baseline: median of up to ten earlier complete sessions with the same sport, posture and device. At least three readings are needed. Intensity and temperature can still affect comparisons.")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                if !previous.isEmpty {
                    Chart(Array(previous.prefix(10).reversed())) { session in
                        if let drop = session.drop(at: 60) {
                            LineMark(x: .value("Date", Date(timeIntervalSince1970: Double(session.workoutEnd))),
                                     y: .value("HRR1", drop))
                                .foregroundStyle(StrandPalette.metricRose)
                            PointMark(x: .value("Date", Date(timeIntervalSince1970: Double(session.workoutEnd))),
                                      y: .value("HRR1", drop))
                                .foregroundStyle(StrandPalette.metricRose)
                        }
                    }
                    .frame(height: NoopMetrics.chartHeight)
                    .accessibilityLabel(Text("Earlier guided HRR1 measurements in beats per minute"))
                }
            }
            .font(StrandFont.body)
            .foregroundStyle(StrandPalette.textPrimary)
        }
        .task(id: record.id) { previous = GuidedRecoveryStore.comparable(to: record) }
    }

    private func recoveryLine(_ label: String, offset: Int) -> some View {
        VStack(alignment: .leading, spacing: NoopMetrics.space1) {
            HStack {
                Text(label)
                Spacer()
                if let drop = record.drop(at: offset) {
                    Text("\(drop) bpm").monospacedDigit()
                } else { Text("–") }
            }
            if let baseline = TimedHeartRateRecovery.baseline(previous.map { $0.drop(at: offset) }) {
                Text("Personal baseline: \(baseline) bpm")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
            } else {
                Text("Personal baseline unavailable — three comparable sessions needed")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
            }
        }
    }
}
#endif
