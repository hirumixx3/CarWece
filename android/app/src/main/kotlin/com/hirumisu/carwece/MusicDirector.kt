package com.hirumisu.carwece

import kotlin.random.Random

internal data class MusicTrack(val id: String, val title: String, val artist: String,
    val file: String, val durationMs: Int)

/** Decoder operations are isolated so playlist and lifecycle use the same tested rules. */
internal interface MusicBackend {
    fun load(track: MusicTrack, loop: Boolean, startMs: Int,
        ready: () -> Unit, completed: () -> Unit, failed: () -> Unit)
    fun play()
    fun pause()
    fun volume(value: Float)
    fun position(): Int
    fun release()
}

internal class MusicDeck(private val ids: List<String>, private val random: Random) {
    private val bag = mutableListOf<String>()
    fun clear() = bag.clear()
    fun selected(id: String) { bag.remove(id) }
    fun next(current: String?, shuffle: Boolean, failed: Set<String>): String? {
        val available = ids.filterNot { it in failed }
        if (available.isEmpty()) return null
        if (!shuffle) {
            val start = ids.indexOf(current)
            for (offset in 1..ids.size) {
                val id = ids[(start + offset).mod(ids.size)]
                if (id !in failed) return id
            }
        }
        bag.removeAll(failed)
        if (bag.isEmpty()) bag.addAll(available.shuffled(random))
        if (bag.size > 1 && bag.first() == current) bag.add(bag.removeAt(0))
        if (bag.size == 1 && bag.first() == current && available.size > 1) {
            bag.clear(); bag.addAll(available.filterNot { it == current }.shuffled(random))
        }
        return bag.removeAt(0)
    }
}

/** All methods and backend callbacks run on Android's main looper. */
internal class MusicDirector(
    tracks: List<MusicTrack>, private val menuIds: List<String>, private val raceIds: List<String>, private val battleIds: List<String>,
    private val backend: MusicBackend, random: Random = Random.Default,
    private val changed: (Map<String, Any?>) -> Unit = {}
) {
    private val catalog = tracks.associateBy { it.id }
    private val decks = mapOf("menu" to MusicDeck(menuIds, random), "race" to MusicDeck(raceIds, random), "battle" to MusicDeck(battleIds, random))
    private val playlists = mapOf("menu" to menuIds, "race" to raceIds, "battle" to battleIds)
    private val lastPlayed = mutableMapOf<String, String>()
    private fun activeIds() = playlists.getValue(scene)
    private fun deck() = decks.getValue(scene)
    // Menu music is always shuffled, independently of the race/battle preference.
    private fun sceneShuffle() = scene == "menu" || shuffle
    private fun chooseNext() = deck().next(lastPlayed[scene], sceneShuffle(), failed)
    private val failed = mutableSetOf<String>()
    private var generation = 0
    private var ready = false
    private var loaded = false
    private var active = false
    private var focused = false
    private var closed = false
    private var playing = false
    private var gain = .35f
    private var duck = 1f
    private var startMs = 0
    private var error: String? = null
    var scene = "menu"; private set
    var currentId: String? = null; private set
    var shuffle = true; private set
    var userPaused = false; private set

    init {
        require(catalog.size == tracks.size)
        require(playlists.values.all { it.isNotEmpty() && it.size == it.distinct().size })
        require(playlists.values.flatten().toSet().size == tracks.size)
        require(playlists.values.flatten().all { it in catalog })
    }
    fun state(): Map<String, Any?> = mapOf(
        "trackId" to currentId, "scene" to scene, "shuffle" to shuffle,
        "userPaused" to userPaused, "error" to error,
        "status" to when {
            error != null -> "error"
            !active || !focused -> "waiting"
            !ready -> if (loaded) "loading" else "idle"
            playing -> "playing"
            else -> "paused"
        }
    )
    private fun emit() { if (!closed) changed(state()) }
    fun setScene(value: String) {
        if (closed) return
        val next = if (value in playlists) value else "menu"
        if (scene == next) { ensureLoaded(); return }
        scene = next; userPaused = false; failed.clear(); error = null
        choose(chooseNext())
    }
    /** One explicit return to the main menu, never a periodic audio update. */
    fun enterMenu() {
        if (closed) return
        if (scene != "menu") { setScene("menu"); return }
        userPaused = false; failed.clear(); error = null
        choose(chooseNext())
    }
    fun setVolume(value: Float) {
        if (closed) return
        val next = if (value.isFinite()) value.coerceIn(0f, 1f) else .35f
        if (gain == next) return
        gain = next; reconcile()
    }
    fun setDuck(value: Float) { duck = value.coerceIn(0f, 1f); reconcile() }
    fun setFocus(value: Boolean) {
        if (closed || focused == value) return
        focused = value; reconcile()
    }
    fun setActive(value: Boolean) {
        if (closed) return
        val returningToMenu = value && !active && scene == "menu" && currentId != null
        active = value
        if (returningToMenu) {
            // Opening the app again while in a menu starts a fresh draw.
            // Keep an explicit user pause and leave race/battle resume untouched.
            failed.clear(); error = null
            choose(chooseNext())
        } else if (value) ensureLoaded()
        reconcile()
    }
    fun setShuffle(value: Boolean) {
        if (closed || shuffle == value) return
        shuffle = value
        // Do not reset the independent menu shuffle bag when changing this setting.
        decks.filterKeys { it != "menu" }.values.forEach { it.clear() }
        emit()
    }
    fun select(id: String) {
        if (closed || id !in activeIds()) return
        userPaused = false; failed.remove(id); deck().selected(id)
        choose(id)
    }
    fun next() {
        if (closed) return
        userPaused = false
        if (failed.containsAll(activeIds())) failed.clear()
        choose(deck().next(currentId, sceneShuffle(), failed))
    }
    fun setUserPaused(value: Boolean) {
        if (closed) return
        userPaused = value
        if (!userPaused && error != null) { failed.clear(); choose(currentId ?: activeIds().first()) }
        else { ensureLoaded(); reconcile() }
    }
    fun toggle() = setUserPaused(!userPaused)
    private fun choose(id: String?) {
        generation++; backend.release(); ready = false; loaded = false; playing = false
        currentId = id; startMs = 0; error = null
        if (id != null) lastPlayed[scene] = id
        if (id == null) { error = "Não foi possível iniciar a trilha. Toque em PULAR FAIXA para tentar novamente."; emit(); return }
        ensureLoaded(); emit()
    }
    private fun ensureLoaded() {
        if (closed || !active || loaded || error != null) return
        if (currentId == null) currentId = chooseNext()
        val track = catalog[currentId] ?: return
        // Also remember the initial draw (not just tracks selected by choose()).
        lastPlayed[scene] = track.id
        loaded = true; ready = false; val token = ++generation
        try {
            backend.load(track, false, startMs, {
                if (!closed && token == generation) { ready = true; startMs = 0; reconcile() }
            }, {
                if (!closed && token == generation) {
                    choose(deck().next(currentId, sceneShuffle(), failed))
                }
            }, { fail(token) })
        } catch (_: Exception) { fail(token) }
    }
    private fun fail(token: Int) {
        if (closed || token != generation) return
        currentId?.let { failed.add(it) }
        val next = deck().next(currentId, sceneShuffle(), failed)
        if (next != null) { choose(next); return }
        generation++; backend.release(); loaded = false; ready = false; playing = false
        error = "Não foi possível iniciar a trilha. Toque em PULAR FAIXA para tentar novamente."
        emit()
    }
    private fun reconcile() {
        if (closed) return
        try {
            if (ready) backend.volume(gain * duck)
            val shouldPlay = active && focused && ready && gain > 0 && !userPaused
            if (shouldPlay && !playing) { playing = true; backend.play() }
            else if (!shouldPlay && playing) { playing = false; backend.pause() }
        } catch (_: Exception) { fail(generation); return }
        emit()
    }
    /** Release the decoder in onStop, retaining the track and its seek position. */
    fun suspend() {
        if (closed) return
        active = false
        if (loaded) {
            startMs = if (ready) try { backend.position().coerceAtLeast(0) } catch (_: Exception) { 0 } else startMs
            generation++; backend.release(); loaded = false; ready = false; playing = false
        }
        emit()
    }
    fun close() {
        if (closed) return
        closed = true; generation++; backend.release(); loaded = false; ready = false; playing = false
    }
}
