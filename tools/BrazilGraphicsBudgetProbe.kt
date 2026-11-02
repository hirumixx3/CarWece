package com.hirumisu.carwece

/** Standalone JVM check of the production Flutter/Android payload validator.
 * This verifies contract bounds; it is not an APK build or an EGL test. */
fun main() {
    val triangle = FloatArray(36)
    val inventory = List(324) { triangle }
    val shaders = List(4) { "void main() {}" }
    fun frame(index: Int = 323): FloatArray = FloatArray(32).also {
        it[14] = 1f; it[15] = index.toFloat()
        for (j in listOf(16, 21, 26, 31)) it[j] = 1f
    }
    fun rejects(name: String, run: () -> Unit) {
        var rejected = false
        try { run() } catch (e: IllegalArgumentException) { rejected = true }
        check(rejected) { "Invalid payload accepted: $name" }
        println("PASS reject: $name")
    }
    check(GraphicsContract.MAX_MESHES == 512)
    GraphicsContract.validateCreate(triangle, inventory, shaders, frame())
    println("PASS accept: 324 mesh slots, including mesh index 323")
    rejects("513 mesh slots") { GraphicsContract.validateCreate(triangle, List(513) { triangle }, shaders, frame()) }
    rejects("mesh index 324 outside 324 slots") { GraphicsContract.validateCreate(triangle, inventory, shaders, frame(324)) }
    rejects("truncated triangle") { GraphicsContract.validateCreate(FloatArray(35), inventory, shaders, frame()) }
    rejects("nonfinite transform") { GraphicsContract.validateCreate(triangle, inventory, shaders, frame().also { it[16] = Float.NaN }) }
    rejects("129 instances") {
        val f = FloatArray(15 + 129 * 17); f[14] = 129f
        GraphicsContract.validateCreate(triangle, inventory, shaders, f)
    }
    println("All 6 native budget checks passed; instance budget remains 128.")
}
