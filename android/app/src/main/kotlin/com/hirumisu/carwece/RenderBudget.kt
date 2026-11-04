package com.hirumisu.carwece

/** Sustained presentation cost, not a promise of device FPS. Hysteresis keeps
 * temporary stalls and resume/loading from repeatedly resizing the scene. */
internal class RenderBudget(
    private val climbSamples: Int = 480,
    private val climbBelowMs: Double = 17.8
) {
    private val scales=floatArrayOf(.55f,.70f,.85f,1f)
    var level=2; private set
    val scale: Float get()=scales[level]
    private var average=16.0
    private var samples=0; private var slow=0; private var fast=0
    fun reset() { average=16.0; samples=0; slow=0; fast=0 }
    fun sample(milliseconds: Double): Boolean {
        if(!milliseconds.isFinite() || milliseconds<=0 || milliseconds>250)return false
        average=average*.92+milliseconds*.08
        samples++
        if(samples<45)return false
        slow=if(average>23.5)slow+1 else 0
        fast=if(average<climbBelowMs)fast+1 else 0
        if(slow>=24 && level>0) { level--; reset(); return true }
        if(fast>=climbSamples && level<scales.lastIndex) { level++; reset(); return true }
        return false
    }
}
