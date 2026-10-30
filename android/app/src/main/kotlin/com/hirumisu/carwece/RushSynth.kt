package com.hirumisu.carwece

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.*

/** Engine and gameplay effects only; MP3 music is handled by RushMusic. */
internal class RushSynth {
    @Volatile var active = false
    @Volatile var duck = 1.0
    @Volatile private var running = true
    @Volatile private var effects = 0.7
    @Volatile private var speed = 0.0
    @Volatile private var racing = false
    @Volatile private var turbo = false
    private val event = AtomicInteger(0)
    private val worker = Thread({ render() }, "CarWeceAudio").apply { isDaemon = true; start() }

    fun update(args: Map<*, *>) {
        effects = ((args["effects"] as? Number)?.toDouble() ?: effects).coerceIn(0.0, 1.0)
        speed = ((args["speed"] as? Number)?.toDouble() ?: 0.0).coerceIn(0.0, 1.6)
        racing = args["racing"] == true
        turbo = args["turbo"] == true
        val name = args["event"] as? String
        if (name != null) event.set(when (name) {
            "tap" -> 1; "pickup", "lap", "go" -> 2
            "bump", "land" -> 3; "boost", "jump", "item" -> 4
            "hit", "explosion" -> 5; "finish" -> 6
            "gun" -> 7; "laser" -> 8; "electric" -> 9
            "shield", "repair", "missile" -> 4; else -> 0
        })
    }
    fun close() { running = false; worker.interrupt() }

    private fun render() {
        var track: AudioTrack? = null
        try {
            val rate = 22050
            val minimum = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
            if (minimum <= 0) return
            track = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
                .setTransferMode(AudioTrack.MODE_STREAM).setBufferSizeInBytes(max(minimum, 4096)).build()
            val buffer = ShortArray(512)
            var phase = 0.0; var effectType = 0; var effectAge = 9.0
            var playing = false
            while (running) {
                if (!active) {
                    if (playing) { track.pause(); track.flush(); playing = false }
                    Thread.sleep(50); continue
                }
                val next = event.getAndSet(0)
                if (next != 0) { effectType = next; effectAge = 0.0 }
                val ev = effects * duck; val rev = speed
                val onTrack = racing; val boosting = turbo
                if(ev<=0 || (!onTrack && effectAge>=.65)) {
                    // Menu music has its own MediaPlayer. Do not synthesize and
                    // submit silent PCM continuously while only music is audible.
                    if(playing) { track.pause();track.flush();playing=false }
                    if(ev<=0)effectAge=9.0
                    Thread.sleep(20);continue
                }
                if (!playing) { track.play(); playing = true }
                val increment=2*PI*(45+rev*125+if(boosting)30 else 0)/rate
                val sampleTime=1.0/rate
                val decay=if(effectType==7)48.0 else if(effectType==1)35.0 else 7.0
                for (i in buffer.indices) {
                    phase += increment
                    if (phase > 2 * PI) phase -= 2 * PI
                    val engine = if (onTrack) (sin(phase) * .065 + sin(phase * 2) * .025) * ev else 0.0
                    val sfx = if (effectAge < .65) {
                        val frequency = when (effectType) {
                            1 -> 780.0; 2 -> 620.0 + effectAge * 1500
                            3 -> 95.0; 4 -> 170.0 + effectAge * 1200
                            5 -> 140.0; 7 -> 145.0 + sin(effectAge * 17000) * 90
                            8 -> 1600.0 - effectAge * 1900; 9 -> 440.0 + sin(effectAge * 480) * 310
                            else -> 440.0 + floor(effectAge * 10) * 80
                        }
                        sin(effectAge * 2 * PI * frequency) * exp(-effectAge * decay) * .25 * ev
                    } else 0.0
                    buffer[i] = ((engine + sfx).coerceIn(-.9, .9) * 32767).toInt().toShort()
                    effectAge += sampleTime
                }
                if (track.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING) < 0) break
            }
        } catch (_: Exception) {
            // Hardware audio failures never crash the game.
        } finally {
            try { track?.pause(); track?.flush(); track?.release() } catch (_: Exception) { }
        }
    }
}
