package com.hirumisu.carwece

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.view.TextureRegistry

internal class AndroidIntroBackend(private val context: Context, private val surface: Surface,
    private val size: (Int, Int) -> Unit) : IntroBackend {
    private var player: MediaPlayer? = null
    private var prepared = false
    private var started = false
    override fun load(ready: (Int, Int, Int) -> Unit, completed: () -> Unit, failed: () -> Unit) {
        release()
        val next = MediaPlayer(); player = next
        next.setOnErrorListener { p, _, _ ->
            if (p === player) { prepared = false; started = false; failed() }; true
        }
        next.setOnCompletionListener { p ->
            if (p === player) { started = false; completed() }
        }
        next.setOnVideoSizeChangedListener { p, w, h ->
            if (p === player && w > 0 && h > 0) size(w, h)
        }
        next.setOnPreparedListener { p ->
            if (p !== player) return@setOnPreparedListener
            try {
                p.isLooping = false
                p.setVolume(1f, 1f)
                val width = if (p.videoWidth > 0) p.videoWidth else 1280
                val height = if (p.videoHeight > 0) p.videoHeight else 720
                size(width, height)
                prepared = true
                ready(width, height, p.duration)
            } catch (_: Exception) { failed() }
        }
        try {
            next.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
            next.setSurface(surface)
            context.assets.openFd("flutter_assets/assets/video/carwece_intro.mp4").use {
                next.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            next.prepareAsync()
        } catch (_: Exception) { failed() }
    }
    override fun play() { if (prepared && !started) { player?.start(); started = true } }
    override fun pause() { if (prepared && started) { player?.pause(); started = false } }
    override fun release() {
        val old = player; player = null; prepared = false; started = false
        try { old?.setOnPreparedListener(null); old?.setOnCompletionListener(null)
            old?.setOnErrorListener(null); old?.setOnVideoSizeChangedListener(null)
            old?.release() } catch (_: Exception) { }
    }
}

internal class RushIntro(private val context: Context,
    private val entry: TextureRegistry.SurfaceTextureEntry,
    private val changed: (Map<String, Any?>) -> Unit,
    private val finished: () -> Unit) {
    private val surface = Surface(entry.surfaceTexture())
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var foreground = false
    private var requested = false
    private var focus = false
    private var closed = false
    private var sentCompletion = false
    private val director = IntroDirector(AndroidIntroBackend(context, surface) { w, h ->
        if (!closed && w > 0 && h > 0) entry.surfaceTexture().setDefaultBufferSize(w, h)
    }) { value ->
        if (value["status"] == "completed" && !sentCompletion) {
            sentCompletion = true; abandon(); changed(state()); finished()
        } else if (!closed) changed(value + ("textureId" to entry.id()))
    }
    private val listener = AudioManager.OnAudioFocusChangeListener { event ->
        if (!closed) when (event) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                focus = requested && foreground; director.setFocus(focus)
            }
            AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                focus = false
                if (event == AudioManager.AUDIOFOCUS_LOSS) requested = false
                director.setFocus(false)
            }
        }
    }
    private val request = if (Build.VERSION.SDK_INT >= 26)
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
            .setOnAudioFocusChangeListener(listener, Handler(Looper.getMainLooper())).build() else null
    fun state(): Map<String, Any?> = director.state() + ("textureId" to entry.id())
    private fun obtain() {
        if (closed || !foreground || sentCompletion || focus || requested) return
        requested = true
        val result = if (Build.VERSION.SDK_INT >= 26) audio.requestAudioFocus(request!!)
            else { @Suppress("DEPRECATION") audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT) }
        focus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        if (!focus) requested = false
        director.setFocus(focus)
    }
    private fun abandon() {
        requested = false; focus = false
        if (Build.VERSION.SDK_INT >= 26) audio.abandonAudioFocusRequest(request!!)
        else { @Suppress("DEPRECATION") audio.abandonAudioFocus(listener) }
    }
    fun open() { director.open(); obtain() }
    fun setForeground(value: Boolean) {
        if (closed) return
        foreground = value; director.setForeground(value)
        if (value) obtain() else { director.setFocus(false); abandon() }
    }
    fun close() {
        if (closed) return
        closed = true; director.close(); abandon(); surface.release(); entry.release()
    }
}
