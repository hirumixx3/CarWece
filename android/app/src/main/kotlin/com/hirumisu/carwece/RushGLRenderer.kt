package com.hirumisu.carwece

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES30 as GL
import android.opengl.Matrix
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.*

/** A GPU renderer presented as a Flutter texture, leaving Flutter in charge of UI/input. */
internal class RushGLRenderer(
    private val entry: TextureRegistry.SurfaceTextureEntry,
    private val width: Int,
    private val height: Int,
    worldVertices: FloatArray,
    objectVertices: List<FloatArray>,
    private val shaderSources: List<String>,
    initialFrame: FloatArray,
    private val showroom: Boolean,
    private val night: Boolean,
    private val quality: String,
    private val onReady: (String?) -> Unit
) {
    val id: Long get() = entry.id()
    @Volatile private var running = true
    @Volatile private var paused = false
    @Volatile private var frame = initialFrame
    @Volatile var error: String? = null
        private set
    private val version = AtomicLong(1)
    private val frameSignal=Object()
    @Volatile private var resetBudget=false
    private var pendingWorld: FloatArray? = worldVertices
    private var pendingObjects: List<FloatArray>? = objectVertices
    private val main = Handler(Looper.getMainLooper())
    private val worker = Thread({ runRenderer() }, "CarWeceGLES-$id")
    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var surface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var androidSurface: Surface? = null
    private val projection = FloatArray(16)
    private val view = FloatArray(16)
    private val vp = FloatArray(16)
    private val lightVP = FloatArray(16)
    private val lightView = FloatArray(16)
    private val lightProjection = FloatArray(16)
    private val identity = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
    private var sceneProgram = 0
    private var depthProgram = 0
    private var shadowFbo = 0
    private var shadowTexture = 0
    private val automatic = quality == "auto"
    private val budget = RenderBudget()
    private val shadowSize = if (quality == "high") 2048 else if (quality == "low") 512 else if(automatic)768 else 1024
    private data class Mesh(val buffer: Int, val elements: Int, val vao: Int,
        val count: Int, val bounds: RenderGeometry.Bounds,
        val transparent: Boolean, val castsShadow: Boolean)
    private val world = mutableListOf<Mesh>()
    private var vertexScratch: ByteBuffer? = null
    private var indexScratch: ByteBuffer? = null
    private val objects = mutableListOf<Mesh>()
    private val cameraFrustum=RenderGeometry.Frustum()
    private val shadowFrustum=RenderGeometry.Frustum()
    private val uniforms=HashMap<Int,HashMap<String,Int>>()
    private var sceneFbo=0; private var sceneColor=0; private var sceneDepth=0
    private var ready = false
    @Volatile var presentedFps=0.0
        private set
    private var fpsAt=0L; private var presented=0

    fun start() { worker.isDaemon = true; worker.start() }
    fun update(data: FloatArray) { if (data.size >= 15 && running) {
        synchronized(frameSignal) { frame = data; version.incrementAndGet(); frameSignal.notifyAll() }
    } }
    fun setPaused(value: Boolean) { synchronized(frameSignal) {
        paused = value
        if (!value) { resetBudget=true; version.incrementAndGet() }
        frameSignal.notifyAll()
    } }
    fun close() { running = false; worker.interrupt() }

    private fun initEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "Display EGL indisponível" }
        val versionOut = IntArray(2)
        check(EGL14.eglInitialize(display, versionOut, 0, versionOut, 1)) { "Falha ao iniciar EGL" }
        fun config(samples: Int): EGLConfig? {
            val attrs = intArrayOf(EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_RENDERABLE_TYPE, 0x0040, EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_DEPTH_SIZE, 24, EGL14.EGL_SAMPLE_BUFFERS, if (samples > 0) 1 else 0,
                EGL14.EGL_SAMPLES, samples, EGL14.EGL_NONE)
            val configs = arrayOfNulls<EGLConfig>(1); val count = IntArray(1)
            if (!EGL14.eglChooseConfig(display, attrs, 0, configs, 0, 1, count, 0) || count[0] == 0) return null
            return configs[0]
        }
        val selected = (if (quality == "high") config(4) else null) ?: config(0)
        check(selected != null) { "OpenGL ES 3.0 não disponível" }
        context = EGL14.eglCreateContext(display, selected, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE), 0)
        check(context != EGL14.EGL_NO_CONTEXT) { "Contexto OpenGL ES 3.0 indisponível" }
        androidSurface = Surface(entry.surfaceTexture())
        surface = EGL14.eglCreateWindowSurface(display, selected, androidSurface, intArrayOf(EGL14.EGL_NONE), 0)
        check(surface != EGL14.EGL_NO_SURFACE) { "Falha ao criar superfície gráfica" }
        check(EGL14.eglMakeCurrent(display, surface, surface, context)) { "Falha ao ativar contexto gráfico" }
        EGL14.eglSwapInterval(display, 1)
    }

    private fun shader(kind: Int, source: String): Int {
        val shader = GL.glCreateShader(kind)
        GL.glShaderSource(shader, source); GL.glCompileShader(shader)
        val ok = IntArray(1); GL.glGetShaderiv(shader, GL.GL_COMPILE_STATUS, ok, 0)
        check(ok[0] != 0) { "Shader: ${GL.glGetShaderInfoLog(shader)}" }
        return shader
    }
    private fun program(vertex: String, fragment: String): Int {
        val v = shader(GL.GL_VERTEX_SHADER, vertex); val f = shader(GL.GL_FRAGMENT_SHADER, fragment)
        val p = GL.glCreateProgram(); GL.glAttachShader(p, v); GL.glAttachShader(p, f); GL.glLinkProgram(p)
        val ok = IntArray(1); GL.glGetProgramiv(p, GL.GL_LINK_STATUS, ok, 0)
        check(ok[0] != 0) { "Programa 3D: ${GL.glGetProgramInfoLog(p)}" }
        GL.glDeleteShader(v); GL.glDeleteShader(f); return p
    }
    private fun upload(data: FloatArray): Mesh {
        require(data.size % 36 == 0) { "Malha 3D inválida" }
        val packed=RenderGeometry.index(data)
        val handle = IntArray(2); GL.glGenBuffers(2, handle, 0)
        val vaos=IntArray(1); GL.glGenVertexArrays(1,vaos,0); GL.glBindVertexArray(vaos[0])
        try {
        val buffer = RenderGeometry.compact(packed.vertices,vertexScratch)
        vertexScratch=buffer
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, handle[0])
        GL.glBufferData(GL.GL_ARRAY_BUFFER, buffer.remaining(), buffer, GL.GL_STATIC_DRAW)
        val indexBytes=packed.indices.size*4
        val scratch=(indexScratch?.takeIf { it.capacity()>=indexBytes }
            ?: ByteBuffer.allocateDirect(indexBytes)).order(ByteOrder.nativeOrder())
        indexScratch=scratch; scratch.clear(); scratch.limit(indexBytes)
        val indices=scratch.asIntBuffer()
        indices.put(packed.indices).position(0)
        GL.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER,handle[1])
        GL.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER,packed.indices.size*4,indices,GL.GL_STATIC_DRAW)
        for(i in 0..4)GL.glEnableVertexAttribArray(i)
        GL.glVertexAttribPointer(0,3,GL.GL_FLOAT,false,32,0)
        GL.glVertexAttribPointer(1,3,GL.GL_SHORT,true,32,12)
        GL.glVertexAttribPointer(2,3,GL.GL_UNSIGNED_BYTE,true,32,18)
        GL.glVertexAttribPointer(3,2,GL.GL_FLOAT,false,32,24)
        GL.glVertexAttribPointer(4,1,GL.GL_UNSIGNED_BYTE,false,32,21)
        GL.glBindVertexArray(0)
        return Mesh(handle[0],handle[1],vaos[0],packed.indices.size,RenderGeometry.Bounds.of(data),
            GraphicsContract.isTransparentMesh(data), GraphicsContract.castsShadowMesh(data))
        } catch (error: Throwable) {
            GL.glBindVertexArray(0)
            GL.glDeleteBuffers(2,handle,0); GL.glDeleteVertexArrays(1,vaos,0)
            throw error
        }
    }
    private fun initShadow() {
        val ids = IntArray(1); GL.glGenTextures(1, ids, 0); shadowTexture = ids[0]
        GL.glBindTexture(GL.GL_TEXTURE_2D, shadowTexture)
        GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_DEPTH_COMPONENT24, shadowSize, shadowSize, 0,
            GL.GL_DEPTH_COMPONENT, GL.GL_UNSIGNED_INT, null)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
        GL.glGenFramebuffers(1, ids, 0); shadowFbo = ids[0]
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, shadowFbo)
        GL.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_DEPTH_ATTACHMENT, GL.GL_TEXTURE_2D, shadowTexture, 0)
        GL.glDrawBuffers(1, intArrayOf(GL.GL_NONE), 0); GL.glReadBuffer(GL.GL_NONE)
        check(GL.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER) == GL.GL_FRAMEBUFFER_COMPLETE) { "Mapa de sombras indisponível" }
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)
    }
    private fun uniform(program: Int, name: String): Int =
        uniforms.getOrPut(program){HashMap()}.getOrPut(name){GL.glGetUniformLocation(program,name)}
    private fun matrix(program: Int, name: String, data: FloatArray, offset: Int = 0) {
        GL.glUniformMatrix4fv(uniform(program, name), 1, false, data, offset)
    }
    private fun vec3(program: Int, name: String, x: Float, y: Float, z: Float) {
        GL.glUniform3f(uniform(program, name), x, y, z)
    }
    private fun scalar(program: Int, name: String, x: Float) { GL.glUniform1f(uniform(program, name), x) }
    private fun draw(mesh: Mesh, program: Int, model: FloatArray, offset: Int = 0) {
        matrix(program, "uModel", model, offset)
        GL.glBindVertexArray(mesh.vao)
        GL.glDrawElements(GL.GL_TRIANGLES,mesh.count,GL.GL_UNSIGNED_INT,0)
    }
    private fun drawWorld(program: Int, frustum: RenderGeometry.Frustum, forShadow: Boolean = false) {
        matrix(program,"uModel",identity)
        for(mesh in world)if((!forShadow || mesh.castsShadow) && frustum.visible(mesh.bounds)) {
            GL.glBindVertexArray(mesh.vao)
            GL.glDrawElements(GL.GL_TRIANGLES,mesh.count,GL.GL_UNSIGNED_INT,0)
        }
    }
    private fun initSceneTarget() {
        if(!automatic)return
        val ids=IntArray(1)
        GL.glGenTextures(1,ids,0); sceneColor=ids[0]; GL.glBindTexture(GL.GL_TEXTURE_2D,sceneColor)
        GL.glTexImage2D(GL.GL_TEXTURE_2D,0,GL.GL_RGBA8,width,height,0,GL.GL_RGBA,GL.GL_UNSIGNED_BYTE,null)
        GL.glTexParameteri(GL.GL_TEXTURE_2D,GL.GL_TEXTURE_MIN_FILTER,GL.GL_LINEAR)
        GL.glTexParameteri(GL.GL_TEXTURE_2D,GL.GL_TEXTURE_MAG_FILTER,GL.GL_LINEAR)
        GL.glGenRenderbuffers(1,ids,0); sceneDepth=ids[0]
        GL.glBindRenderbuffer(GL.GL_RENDERBUFFER,sceneDepth)
        GL.glRenderbufferStorage(GL.GL_RENDERBUFFER,GL.GL_DEPTH_COMPONENT24,width,height)
        GL.glGenFramebuffers(1,ids,0); sceneFbo=ids[0]; GL.glBindFramebuffer(GL.GL_FRAMEBUFFER,sceneFbo)
        GL.glFramebufferTexture2D(GL.GL_FRAMEBUFFER,GL.GL_COLOR_ATTACHMENT0,GL.GL_TEXTURE_2D,sceneColor,0)
        GL.glFramebufferRenderbuffer(GL.GL_FRAMEBUFFER,GL.GL_DEPTH_ATTACHMENT,GL.GL_RENDERBUFFER,sceneDepth)
        check(GL.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER)==GL.GL_FRAMEBUFFER_COMPLETE){"Alvo gráfico indisponível"}
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER,0)
    }

    private fun render(data: FloatArray) {
        if (data.size < 15 || data.any { !it.isFinite() }) return
        val count = data[14].toInt().coerceIn(0, GraphicsContract.MAX_INSTANCES)
        if (data.size != 15 + count * 17) return
        val near = if (showroom) 0.1f else .18f
        Matrix.perspectiveM(projection, 0, if (showroom) 40f else 50f, width.toFloat()/height, near, 2600f)
        // Driving coordinates use +right/+forward as in the Dart simulation.
        // Mirror the projection for the race, keeping screen-right steering positive.
        if (!showroom) projection[0] = -projection[0]
        GL.glFrontFace(if (showroom) GL.GL_CCW else GL.GL_CW)
        Matrix.setLookAtM(view, 0, data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8])
        Matrix.multiplyMM(vp, 0, projection, 0, view, 0)
        cameraFrustum.set(vp)
        val lx = -.52f; val ly = .76f; val lz = -.39f
        val cx = data[10]; val cy = data[11]; val cz = data[12]
        Matrix.setLookAtM(lightView, 0, cx+lx*230,cy+ly*230,cz+lz*230,cx,cy,cz,0f,1f,0f)
        val span = if (showroom) 9f else 105f
        Matrix.orthoM(lightProjection, 0, -span,span,-span,span,1f,650f)
        Matrix.multiplyMM(lightVP, 0, lightProjection, 0, lightView, 0)
        shadowFrustum.set(lightVP)
        GL.glEnable(GL.GL_DEPTH_TEST); GL.glDepthFunc(GL.GL_LEQUAL)
        GL.glDisable(GL.GL_CULL_FACE); GL.glDisable(GL.GL_BLEND); GL.glDepthMask(true)
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, shadowFbo)
        GL.glViewport(0,0,shadowSize,shadowSize); GL.glClear(GL.GL_DEPTH_BUFFER_BIT)
        GL.glEnable(GL.GL_POLYGON_OFFSET_FILL); GL.glPolygonOffset(1.3f,2.0f)
        GL.glUseProgram(depthProgram); matrix(depthProgram,"uLightVP",lightVP)
        drawWorld(depthProgram,shadowFrustum,true)
        for (i in 0 until count) {
            val offset=15+i*17; val mesh=data[offset].toInt()
            if (mesh in objects.indices && !objects[mesh].transparent && objects[mesh].castsShadow &&
                shadowFrustum.visible(objects[mesh].bounds,data,offset+1)) draw(objects[mesh],depthProgram,data,offset+1)
        }
        GL.glDisable(GL.GL_POLYGON_OFFSET_FILL)
        val rw=if(automatic)(width*budget.scale).toInt() else width
        val rh=if(automatic)(height*budget.scale).toInt() else height
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER,sceneFbo); GL.glViewport(0,0,rw,rh)
        GL.glEnable(GL.GL_SCISSOR_TEST); GL.glScissor(0,0,rw,rh)
        if (showroom) GL.glClearColor(.046f,.078f,.125f,1f)
        else if (night) GL.glClearColor(.10f,.15f,.26f,1f)
        else GL.glClearColor(.40f,.53f,.63f,1f)
        GL.glClear(GL.GL_COLOR_BUFFER_BIT or GL.GL_DEPTH_BUFFER_BIT)
        GL.glDisable(GL.GL_SCISSOR_TEST)
        GL.glUseProgram(sceneProgram); matrix(sceneProgram,"uVP",vp); matrix(sceneProgram,"uLightVP",lightVP)
        vec3(sceneProgram,"uCamera",data[0],data[1],data[2]); vec3(sceneProgram,"uLight",lx,ly,lz)
        if (night) {
            vec3(sceneProgram,"uSunColor",.62f,.76f,1.10f); vec3(sceneProgram,"uSky",.17f,.26f,.47f)
        } else {
            vec3(sceneProgram,"uSunColor",1.14f,1.01f,.87f); vec3(sceneProgram,"uSky",.46f,.62f,.76f)
        }
        scalar(sceneProgram,"uTime",data[9]); scalar(sceneProgram,"uNight",if(night)1f else 0f)
        scalar(sceneProgram,"uShadowTexel",1f/shadowSize)
        scalar(sceneProgram,"uShadowQuality",if(quality=="low" || (automatic && budget.level==0))0f else if(quality=="high")2f else 1f)
        GL.glActiveTexture(GL.GL_TEXTURE0); GL.glBindTexture(GL.GL_TEXTURE_2D,shadowTexture)
        GL.glUniform1i(uniform(sceneProgram,"uDepth"),0)
        drawWorld(sceneProgram,cameraFrustum)
        for (pass in 0..1) {
            if (pass == 1) { GL.glEnable(GL.GL_BLEND); GL.glBlendFunc(GL.GL_SRC_ALPHA,GL.GL_ONE_MINUS_SRC_ALPHA); GL.glDepthMask(false) }
            // Transparent effects must blend far-to-near; in packet order a
            // near smoke puff could be overwritten by a farther shield.
            val order = if (pass == 0) (0 until count).toList() else (0 until count).sortedByDescending { i ->
                val offset=15+i*17
                val dx=data[offset+13]-data[0]; val dy=data[offset+14]-data[1]; val dz=data[offset+15]-data[2]
                dx*dx+dy*dy+dz*dz
            }
            for (i in order) {
                val offset=15+i*17; val mesh=data[offset].toInt()
                if (mesh !in objects.indices) continue
                if (objects[mesh].transparent != (pass == 1)) continue
                if (!cameraFrustum.visible(objects[mesh].bounds,data,offset+1)) continue
                draw(objects[mesh],sceneProgram,data,offset+1)
            }
        }
        GL.glDepthMask(true); GL.glDisable(GL.GL_BLEND)
        if(automatic) {
            GL.glBindFramebuffer(GL.GL_READ_FRAMEBUFFER,sceneFbo)
            GL.glBindFramebuffer(GL.GL_DRAW_FRAMEBUFFER,0)
            GL.glBlitFramebuffer(0,0,rw,rh,0,0,width,height,GL.GL_COLOR_BUFFER_BIT,GL.GL_LINEAR)
            GL.glBindFramebuffer(GL.GL_FRAMEBUFFER,0)
        }
        check(EGL14.eglSwapBuffers(display,surface)) { "Falha ao apresentar quadro OpenGL" }
    }

    private fun initGeometry() {
        // Keep temporary unpacked/indexed arrays off the long-lived render loop's stack.
        RenderGeometry.forEachChunk(pendingWorld!!) { block ->
            if(!running)throw InterruptedException()
            world.add(upload(block))
        }
        pendingWorld=null
        pendingObjects!!.forEach {
            if(!running)throw InterruptedException()
            objects.add(upload(it))
        }
        pendingObjects=null
        vertexScratch=null; indexScratch=null
    }

    private fun runRenderer() {
        try {
            GraphicsContract.validateCreate(pendingWorld!!,pendingObjects!!,shaderSources,frame)
            initEgl()
            sceneProgram=program(shaderSources[0],shaderSources[1])
            depthProgram=program(shaderSources[2],shaderSources[3])
            initGeometry()
            initShadow(); initSceneTarget()
            check(GL.glGetError()==GL.GL_NO_ERROR) { "Falha ao preparar os recursos OpenGL" }
            var lastVersion = -1L
            var lastPresentationStart=0L
            while (running) {
                synchronized(frameSignal) {
                    while(running && (paused || version.get()==lastVersion))frameSignal.wait()
                }
                if(!running)break
                val next=version.get()
                if(resetBudget) { budget.reset(); resetBudget=false; fpsAt=0L; presented=0; lastPresentationStart=0L }
                val began=System.nanoTime()
                if(fpsAt==0L)fpsAt=began
                render(frame); lastVersion=next
                val ended=System.nanoTime()
                if(automatic) {
                    val cost=(ended-began)/1_000_000.0
                    val cadence=if(lastPresentationStart==0L)cost else (began-lastPresentationStart)/1_000_000.0
                    budget.sample(max(cost,cadence))
                }
                lastPresentationStart=began
                presented++
                if(ended-fpsAt>=1_000_000_000L) {
                    presentedFps=presented*1_000_000_000.0/(ended-fpsAt); presented=0;fpsAt=ended
                }
                if (!ready) { ready=true; main.post { onReady(null) } }
            }
        } catch (_: InterruptedException) {
            if (!ready) main.post { onReady("Renderização interrompida") }
        } catch (exception: Throwable) {
            error=exception.message ?: "Falha gráfica"
            if (!ready) main.post { onReady(error) }
        } finally {
            try {
                pendingWorld=null; pendingObjects=null
                vertexScratch=null; indexScratch=null
                val meshes=world+objects
                val all=meshes.flatMap { listOf(it.buffer,it.elements) }.toIntArray()
                if(all.isNotEmpty())GL.glDeleteBuffers(all.size,all,0)
                val vaos=meshes.map { it.vao }.toIntArray()
                if(vaos.isNotEmpty())GL.glDeleteVertexArrays(vaos.size,vaos,0)
                if(sceneFbo!=0)GL.glDeleteFramebuffers(1,intArrayOf(sceneFbo),0)
                if(sceneColor!=0)GL.glDeleteTextures(1,intArrayOf(sceneColor),0)
                if(sceneDepth!=0)GL.glDeleteRenderbuffers(1,intArrayOf(sceneDepth),0)
                if(sceneProgram!=0)GL.glDeleteProgram(sceneProgram)
                if(depthProgram!=0)GL.glDeleteProgram(depthProgram)
                if(shadowFbo!=0)GL.glDeleteFramebuffers(1,intArrayOf(shadowFbo),0)
                if(shadowTexture!=0)GL.glDeleteTextures(1,intArrayOf(shadowTexture),0)
                EGL14.eglMakeCurrent(display,EGL14.EGL_NO_SURFACE,EGL14.EGL_NO_SURFACE,EGL14.EGL_NO_CONTEXT)
                if(surface!=EGL14.EGL_NO_SURFACE)EGL14.eglDestroySurface(display,surface)
                if(context!=EGL14.EGL_NO_CONTEXT)EGL14.eglDestroyContext(display,context)
                // Flutter also owns contexts on the default display. Destroy only ours.
                EGL14.eglReleaseThread()
                androidSurface?.release()
            } catch (_: Exception) { }
            main.post { entry.release() }
        }
    }
}
