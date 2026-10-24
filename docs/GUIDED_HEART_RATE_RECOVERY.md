# Guided heart-rate recovery (iPhone)

From an active, unpaused workout, choose End, then **End and measure recovery**.
Stop exercising when selecting Sitting, Standing, or Walking. The workout ends and saves under
the existing save rules; the recovery window does not extend workout duration, GPS, strain, or calories.
Workouts discarded under the existing minimum-duration/data rules do not start a recovery measurement.

Keep the recovery screen open and the selected posture unchanged for two minutes. The session owns
a separate reference to the existing live-HR stream. Backgrounding, leaving the screen, a clock jump,
switching devices, or starting another workout interrupts measurement and retains partial readings.
After process termination, an unfinished measurement is displayed as interrupted rather than resumed.

Each finish/30/60/90/120-second checkpoint uses the median of at least three distinct recorded seconds
in the five-second window ending at the checkpoint. Only newly published sensor HR enters this
measurement; the displayed smoothed HR and timer ticks do not generate samples. Duplicate seconds,
implausible HR, and missing coverage cannot create a reading. HRR1/HRR2 subtract the minute reading
from the finish reading and preserve negative values. No retrospective intensity gate or clinical
fitness thresholds apply to this separate, explicitly timed measurement.

Workout detail displays the locally saved readings. Personal baselines require three prior complete
sessions matching sport, posture, and device, and use the median of up to ten available readings.
The chart shows earlier matching HRR1 results. Intensity, environment, and sensor quality still limit
comparisons. Local session metadata and raw samples use a namespaced UserDefaults side-store;
they are not added to the shared SQLite schema or cross-platform `.noopbak` format. Workout edits
follow the natural key without shifting sensor timestamps. Changing the workout finish time hides
the guided card rather than presenting the measurement as anchored to a different finish time.

The screen is iPhone-only. The pure calculation has Swift and Kotlin implementations and matching
tests; Android's existing retrospective HRR UI is unchanged.

## Validation

New tests: `TimedHeartRateRecoveryTests` (Swift package), `GuidedRecoveryStoreTests` (StrandTests),
and `TimedHeartRateRecoveryTest` (Android JVM). The Kotlin oracle test contains literal output from
the compiled production Swift helper over 92 window/baseline cases, also pinned by the Swift test.
Linux validation compiles the new Foundation-only production files and their XCTest suites in an
isolated harness; this does not compile the full analytics package, SwiftUI screens, or app targets.

Before merging, use macOS/Xcode to generate the project and build both Strand and NOOPiOS, and run
StrandTests. On an iPhone with a supported paired strap:

1. End an eligible-length workout through each posture option. Confirm workout/GPS stop immediately,
   HR continues, the timer completes at two minutes, and saved readings reappear in workout detail.
2. Disconnect across a checkpoint; confirm missing coverage stays a dash. Reconnect and confirm later
   checkpoints use fresh readings rather than filling the gap.
3. Stop early, dismiss the sheet, background/lock the phone, and terminate/relaunch the app. Confirm
   partial results are retained, excluded from baselines, and no recovery stream lease remains active.
4. Switch devices during capture. Confirm interruption and no mixed-device measurements.
5. Collect three complete matching sessions; confirm baseline/history include only previous matching
   sessions. Edit the sport/start time and delete a workout to check side-store association/cleanup.
6. End normally without recovery and test paused/too-short workouts; confirm existing behavior.

These device checks and the Xcode app builds have not been performed in the Linux cloud environment.
