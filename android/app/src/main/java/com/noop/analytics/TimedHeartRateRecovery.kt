package com.noop.analytics

import kotlin.math.roundToInt

/** Pure calculation twin of StrandAnalytics/TimedHeartRateRecovery.swift.
 * The guided measurement UI is currently iPhone-only; calculations stay available on both platforms.
 */
object TimedHeartRateRecovery {
    data class Sample(val ts: Long, val bpm: Int)
    val checkpoints = listOf(0, 30, 60, 90, 120)
    const val duration = 120

    fun reading(samples: List<Sample>, target: Long, observedThrough: Long): Int? {
        if (observedThrough < target) return null
        val values = samples.sortedWith(compareBy<Sample> { it.ts }.thenBy { it.bpm })
            .filter { it.ts in (target - 4)..target && it.bpm in 30..220 }
            .distinctBy { it.ts }.map { it.bpm }
        return if (values.size < 3) null else median(values)
    }

    fun baseline(drops: List<Int?>): Int? {
        val values = drops.filterNotNull().take(10)
        return if (values.size < 3) null else median(values)
    }

    private fun median(values: List<Int>): Int {
        val sorted = values.sorted()
        val middle = sorted.size / 2
        // Swift rounds half away from zero, including negative HRR values.
        return if (sorted.size % 2 == 0) {
            val mean = (sorted[middle - 1] + sorted[middle]) / 2.0
            if (mean < 0) -(-mean).roundToInt() else mean.roundToInt()
        } else sorted[middle]
    }
}
