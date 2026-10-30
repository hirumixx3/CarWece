package com.hirumisu.carwece

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONObject

/** Only one music decoder exists, independently of the lightweight engine/SFX mixer. */
internal class AndroidMusicBackend(private val context: Context) : MusicBackend {
    private var player: MediaPlayer? = null
    private var prepared = false
    private var started = false
    private var level = .35f
    override fun load(track: MusicTrack, loop: Boolean, startMs: Int,
        ready: () -> Unit, completed: () -> Unit, failed: () -> Unit) {
        release()
        val next = MediaPlayer()
        player = next
        next.setOnErrorListener { p, _, _ ->
            if (p === player) { started = false; prepared = false; failed() }
            true
        }
        next.setOnCompletionListener { p ->
            if (p === player) { started = false; completed() }
        }
        next.setOnPreparedListener { p ->
            if (p !== player) return@setOnPreparedListener
            prepared = true
            try {
                p.isLooping = loop
                p.setVolume(level, level)
                if (startMs > 0) {
                    p.setOnSeekCompleteListener { seek ->
                        if (seek === player) { seek.setOnSeekCompleteListener(null); ready() }
                    }
                    if (Build.VERSION.SDK_INT >= 26) p.seekTo(startMs.toLong(), MediaPlayer.SEEK_CLOSEST)
                    else { @Suppress("DEPRECATION") p.seekTo(startMs) }
                } else ready()
            } catch (_: Exception) { failed() }
        }
        try {
            context.assets.openFd("flutter_assets/assets/music/${track.file}").use { asset ->
                next.setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
            }
            next.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            next.prepareAsync()
        } catch (_: Exception) {
            if (next === player) failed()
        }
    }
    override fun play() { if (prepared && !started) { player?.start(); started = true } }
    override fun pause() { if (prepared && started) { player?.pause(); started = false } }
    override fun volume(value: Float) {
        level = value.coerceIn(0f, 1f)
        if (prepared) player?.setVolume(level, level)
    }
    override fun position(): Int = if (prepared) player?.currentPosition ?: 0 else 0
    override fun release() {
        val old = player
        player = null; prepared = false; started = false
        try { old?.setOnPreparedListener(null); old?.setOnCompletionListener(null)
            old?.setOnErrorListener(null); old?.setOnSeekCompleteListener(null); old?.release()
        } catch (_: Exception) { }
    }
}

internal class RushMusic(private val context: Context,
    private val changed: (Map<String, Any?>) -> Unit,
    private val effectsFocus: (Boolean, Double) -> Unit) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var foreground = false
    private var focus = false
    private var requested = false
    private var closed = false
    private var duck = 1.0
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (!closed) when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> if (requested && foreground) {
                focus = true; duck = 1.0; applyFocus()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> { duck = .2; applyFocus() }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> { focus = false; applyFocus() }
            AudioManager.AUDIOFOCUS_LOSS -> { focus = false; requested = false; applyFocus() }
        }
    }
    private val request: AudioFocusRequest? = if (Build.VERSION.SDK_INT >= 26)
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setAcceptsDelayedFocusGain(true)
            .setOnAudioFocusChangeListener(focusListener, handler).build() else null
    private val director: MusicDirector
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) abandon()
        }
    }
    private fun listOfIds(json: JSONObject, key: String): List<String> {
        val a = json.getJSONArray(key)
        return (0 until a.length()).map { a.getString(it) }
    }
    init {
        val json = context.assets.open("flutter_assets/assets/music/catalog.json")
            .bufferedReader().use { JSONObject(it.readText()) }
        val array = json.getJSONArray("tracks")
        val tracks = (0 until array.length()).map { index ->
            val t = array.getJSONObject(index)
            val id = t.getString("id")
            require(id.matches(Regex("[a-z0-9_]+")) && t.getString("file") == "$id.m4a")
            MusicTrack(id, t.getString("title"), t.getString("artist"), t.getString("file"), t.getInt("durationMs"))
        }
        val race = json.getJSONArray("raceIds")
        director = MusicDirector(tracks, listOfIds(json, "menuIds"),
            (0 until race.length()).map { race.getString(it) }, listOfIds(json, "battleIds"), AndroidMusicBackend(context), changed = changed)
        if (Build.VERSION.SDK_INT >= 33)
            context.registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), Context.RECEIVER_NOT_EXPORTED)
        else { @Suppress("DEPRECATION") context.registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)) }
    }
    private fun applyFocus() {
        director.setDuck(duck.toFloat()); director.setFocus(focus && foreground)
        effectsFocus(focus && foreground, duck)
    }
    private fun obtain() {
        if (closed || !foreground || focus || requested) return
        requested = true
        val result = if (Build.VERSION.SDK_INT >= 26) audio.requestAudioFocus(request!!)
            else { @Suppress("DEPRECATION") audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) }
        focus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        if (result == AudioManager.AUDIOFOCUS_REQUEST_FAILED) requested = false
        duck = 1.0; applyFocus()
    }
    private fun abandon() {
        requested = false; focus = false; duck = 1.0; applyFocus()
        if (Build.VERSION.SDK_INT >= 26) audio.abandonAudioFocusRequest(request!!)
        else { @Suppress("DEPRECATION") audio.abandonAudioFocus(focusListener) }
    }
    fun resume() {
        if (closed) return
        foreground = true; director.setActive(true); obtain()
    }
    fun pause() {
        if (closed) return
        foreground = false; director.setActive(false); abandon()
    }
    fun stop() { if (!closed) { pause(); director.suspend() } }
    fun update(args: Map<*, *>) {
        if (closed) return
        director.setVolume(((args["music"] as? Number)?.toFloat() ?: .35f))
        director.setShuffle(args["shuffle"] != false)
        if (args["enterMenu"] == true) director.enterMenu()
        else director.setScene(args["scene"] as? String ?: "menu")
    }
    fun command(action: String, args: Map<*, *>): Map<String, Any?> {
        if (action != "status") {
            obtain()
            if (args["scene"] == "race" || args["scene"] == "battle") director.setScene(args["scene"] as String)
        }
        when (action) {
            "select" -> (args["id"] as? String)?.let { director.select(it) }
            "next" -> director.next()
            "toggle" -> director.toggle()
            "play" -> director.setUserPaused(false)
            "pause" -> director.setUserPaused(true)
            "shuffle" -> director.setShuffle(args["enabled"] != false)
        }
        return director.state()
    }
    fun close() {
        if (closed) return
        pause(); closed = true; director.close()
        try { context.unregisterReceiver(noisy) } catch (_: Exception) { }
    }
}
