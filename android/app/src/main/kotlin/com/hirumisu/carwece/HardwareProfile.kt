package com.hirumisu.carwece

/** Entry-level hardware that cannot hold the full-quality pipeline at a
 * steady frame rate. Devices matched here get their own ceilings inside
 * the renderer (dynamic resolution, half-rate shadow updates, smaller
 * shadow maps, capped frame submission) instead of dropping frames.
 * Anything unknown stays on the full-quality path. */
internal object HardwareProfile {
    fun isLowEnd(model: String, soc: String, totalMemMb: Long): Boolean {
        val m = model.trim().uppercase()
        val s = soc.trim().uppercase()
        if (m.startsWith("SM-A057")) return true // Galaxy A05s, every variant
        if (s == "SM6225") return true // Snapdragon 680: Adreno 610 class
        if ((s.startsWith("MT6765") || s.startsWith("MT6769")) &&
            totalMemMb in 1..6144
        ) return true // Helio G25/G35/G80/G85 class with entry-level RAM
        return false
    }
}
