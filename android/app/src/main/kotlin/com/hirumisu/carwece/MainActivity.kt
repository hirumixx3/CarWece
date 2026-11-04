package com.hirumisu.carwece

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.view.WindowManager
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var synth: RushSynth? = null
    private var soundtrack: RushMusic? = null
    private var intro: RushIntro? = null
    private var introPending = true
    private var foreground = false
    private val graphics = mutableMapOf<Long, RushGLRenderer>()
    private fun hardwareProfile(): Map<String, Any?> {
        val model = android.os.Build.MODEL ?: ""
        val soc = if (android.os.Build.VERSION.SDK_INT >= 31) android.os.Build.SOC_MODEL ?: "" else ""
        var totalMemMb = -1L
        try {
            val info = android.app.ActivityManager.MemoryInfo()
            (getSystemService(android.app.ActivityManager::class.java))?.getMemoryInfo(info)
            if (info.totalMem > 0) totalMemMb = info.totalMem / (1024 * 1024)
        } catch (_: Exception) { }
        return mapOf("model" to model, "soc" to soc, "totalMemMb" to totalMemMb,
            "lowEnd" to HardwareProfile.isLowEnd(model, soc, totalMemMb))
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hirumisu.carwece/host")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "identity" -> Thread {
                        try {
                            val identity = HostIdentity.create()
                            runOnUiThread { result.success(identity) }
                        } catch (e: Exception) { runOnUiThread { result.error("host_identity", "Não foi possível preparar a sala.", null) } }
                    }.start()
                    "start" -> {
                        try {
                            val intent = android.content.Intent(this, FriendHostService::class.java)
                            if (android.os.Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(null)
                        } catch (e: Exception) { result.error("host_service", "Não foi possível iniciar a sala.", null) }
                    }
                    "stop" -> { stopService(android.content.Intent(this, FriendHostService::class.java)); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        val preferences = getSharedPreferences("carwece_v1", MODE_PRIVATE)
        synth = RushSynth()
        val musicChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hirumisu.carwece/music")
        soundtrack = RushMusic(this, { state -> musicChannel.invokeMethod("state", state) }, { enabled, duck ->
            synth?.active = enabled; synth?.duck = duck
        })
        try {
            val saved = preferences.getString("save", null)
            val settings = saved?.let { JSONObject(it).optJSONObject("settings") }
            soundtrack?.update(mapOf("scene" to "menu", "music" to (settings?.optDouble("music", .35) ?: .35),
                "shuffle" to (settings?.optBoolean("musicShuffle", true) ?: true)))
        } catch (_: Exception) { }
        musicChannel.setMethodCallHandler { call, result ->
            if (call.method in setOf("status", "select", "next", "toggle", "shuffle", "play", "pause")) {
                result.success(soundtrack?.command(if (introPending) "status" else call.method, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()))
            } else result.notImplemented()
        }
        val introChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hirumisu.carwece/intro")
        introChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    if (intro == null) {
                        soundtrack?.pause(); synth?.active = false
                        intro = RushIntro(this, flutterEngine.renderer.createSurfaceTexture(),
                            { state -> introChannel.invokeMethod("state", state) }, {
                                introPending = false
                                if (foreground) soundtrack?.resume()
                            })
                        intro?.setForeground(foreground)
                    }
                    intro?.open(); result.success(intro?.state())
                }
                "pause" -> { intro?.setForeground(false); result.success(intro?.state()) }
                "resume" -> { intro?.setForeground(foreground); result.success(intro?.state()) }
                "dispose" -> { intro?.close(); intro = null; result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hirumisu.carwece/graphics")
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                when (call.method) {
                    "profile" -> result.success(hardwareProfile())
                    "create" -> {
                        try {
                            val world = args["world"] as FloatArray
                            val meshes = (args["objects"] as List<*>).map { it as FloatArray }
                            val shaders = (args["shaders"] as List<*>).map { it as String }
                            val initial = args["frame"] as FloatArray
                            val width = ((args["width"] as Number).toInt()).coerceIn(320,1920)
                            val height = ((args["height"] as Number).toInt()).coerceIn(180,1200)
                            val entry = flutterEngine.renderer.createSurfaceTexture()
                            entry.surfaceTexture().setDefaultBufferSize(width,height)
                            val id = entry.id()
                            val renderer = RushGLRenderer(entry,width,height,world,meshes,shaders,initial,
                                args["showroom"] == true,args["night"] == true,args["quality"] as? String ?: "medium",
                                weakGpu = hardwareProfile()["lowEnd"] == true) { error ->
                                if(error==null)result.success(id)
                                else { graphics.remove(id); result.error("graphics_unavailable",error,null) }
                            }
                            graphics[id]=renderer; renderer.start()
                        } catch (e: Exception) { result.error("invalid_graphics",e.message,null) }
                    }
                    "frame" -> {
                        val renderer = graphics[(args["id"] as? Number)?.toLong()]
                        (args["data"] as? FloatArray)?.let { renderer?.update(it) }
                        result.success(renderer?.error)
                    }
                    "fps" -> result.success(graphics[(args["id"] as? Number)?.toLong()]?.presentedFps)
                    "dispose" -> { graphics.remove((args["id"] as? Number)?.toLong())?.close(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hirumisu.carwece/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> result.success(preferences.getString("save", null))
                    "save" -> {
                        val payload = call.arguments as? String
                        if (payload == null || payload.length > 256000) {
                            result.error("invalid_save", "Invalid save", null)
                        } else {
                            Thread {
                                val saved = preferences.edit().putString("save", payload).commit()
                                runOnUiThread {
                                    if (saved) result.success(true)
                                    else result.error("save_failed", "Storage unavailable", null)
                                }
                            }.start()
                        }
                    }
                    "audio" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        if (!introPending) { synth?.update(args); soundtrack?.update(args) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onPause() { foreground = false; intro?.setForeground(false); soundtrack?.pause(); synth?.active = false; graphics.values.forEach { it.setPaused(true) }; super.onPause() }
    override fun onResume() { super.onResume(); foreground = true; intro?.setForeground(true); if (!introPending) soundtrack?.resume(); graphics.values.forEach { it.setPaused(false) } }
    override fun onStop() { soundtrack?.stop(); super.onStop() }
    override fun onDestroy() { intro?.close(); intro = null; soundtrack?.close(); soundtrack = null; graphics.values.forEach { it.close() }; graphics.clear(); synth?.close(); synth = null; super.onDestroy() }
}
