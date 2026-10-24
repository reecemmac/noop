package com.noop.analytics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TimedHeartRateRecoveryTest {
    @Test fun matchesCompiledSwiftOracleAcrossWindowsAndSignedBaselines() {
        val results = mutableListOf<String>()
        for (count in 0..8) for (offset in -6..2) {
            val samples = (0 until count).map {
                TimedHeartRateRecovery.Sample(100L + offset - it, 139 + it % 4)
            }
            results += TimedHeartRateRecovery.reading(samples, 100, 100)?.toString() ?: "nil"
        }
        for (base in -5..5) {
            results += TimedHeartRateRecovery.baseline(listOf(base, base + 1, base + 2, base + 3))?.toString() ?: "nil"
        }
        // Literal stdout of Swift 6.0.3 compiling the production Swift helper, over the same cases.
        assertEquals("nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,140,140,140,nil,nil,nil,nil,nil,nil,140,141,141,141,nil,nil,nil,nil,nil,140,141,140,141,141,nil,nil,nil,nil,140,141,140,140,141,nil,nil,nil,nil,140,141,140,140,141,nil,nil,nil,nil,140,141,140,140,141,-4,-3,-2,-1,1,2,3,4,5,6,7", results.joinToString(","))
    }

    @Test fun missingDuplicateInvalidAndFutureSamplesDoNotCreateReadings() {
        val repeated = List(20) { TimedHeartRateRecovery.Sample(100, 140) }
        assertNull(TimedHeartRateRecovery.reading(repeated, 100, 100))
        val valid = (96L..100L).map { TimedHeartRateRecovery.Sample(it, 140) }
        assertNull(TimedHeartRateRecovery.reading(valid, 100, 99))
        assertNull(TimedHeartRateRecovery.reading(valid, 105, 105))
        assertNull(TimedHeartRateRecovery.reading(valid.map { it.copy(bpm = 0) }, 100, 100))
        assertEquals(140, TimedHeartRateRecovery.reading(valid, 100, 100))
    }

    @Test fun baselineRequiresThreeAndLimitsToTenValidSessions() {
        assertNull(TimedHeartRateRecovery.baseline(listOf(null, 10, 20)))
        assertEquals(20, TimedHeartRateRecovery.baseline(listOf(10, null, 20, 30)))
        assertEquals(20, TimedHeartRateRecovery.baseline(listOf(null) + List(10) { 20 } + listOf(200)))
    }
}
