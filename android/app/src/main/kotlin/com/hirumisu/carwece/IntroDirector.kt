package com.hirumisu.carwece

internal interface IntroBackend {
    fun load(ready: (Int, Int, Int) -> Unit, completed: () -> Unit, failed: () -> Unit)
    fun play()
    fun pause()
    fun release()
}

/** Completion comes exclusively from the decoder, never from a splash timer. */
internal class IntroDirector(private val backend: IntroBackend,
    private val changed: (Map<String, Any?>) -> Unit = {}) {
    private var generation = 0
    private var opened = false
    private var ready = false
    private var foreground = false
    private var focused = false
    private var playing = false
    private var closed = false
    private var error = false
    var completed = false; private set
    private var width = 1280
    private var height = 720
    private var durationMs = 0
    fun state(): Map<String, Any?> = mapOf(
        "status" to when {
            completed -> "completed"
            error -> "error"
            !ready -> "loading"
            playing -> "playing"
            else -> "paused"
        }, "width" to width, "height" to height, "durationMs" to durationMs)
    private fun emit() { if (!closed) changed(state()) }
    fun open() {
        if (closed || (opened && !error)) return
        val token = ++generation
        backend.release(); opened = true; ready = false; playing = false
        completed = false; error = false
        try {
            backend.load({ w, h, duration ->
                if (!closed && token == generation) {
                    if (w <= 0 || h <= 0 || duration <= 0) fail(token)
                    else { width = w; height = h; durationMs = duration; ready = true; reconcile() }
                }
            }, {
                if (!closed && token == generation && ready && !completed) {
                    completed = true; playing = false; emit()
                }
            }, { fail(token) })
        } catch (_: Exception) { fail(token) }
        emit()
    }
    private fun fail(token: Int) {
        if (closed || token != generation || completed) return
        generation++; ready = false; playing = false; error = true
        backend.release(); emit()
    }
    private fun reconcile() {
        if (closed) return
        val shouldPlay = ready && foreground && focused && !completed && !error
        try {
            if (shouldPlay && !playing) { backend.play(); playing = true }
            else if (!shouldPlay && playing) { backend.pause(); playing = false }
        } catch (_: Exception) { fail(generation); return }
        emit()
    }
    fun setForeground(value: Boolean) { foreground = value; reconcile() }
    fun setFocus(value: Boolean) { focused = value; reconcile() }
    fun close() {
        if (closed) return
        closed = true; generation++; backend.release(); playing = false
    }
}
