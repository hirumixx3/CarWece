package com.hirumisu.carwece

import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class GraphicsContractTest {
    private fun request(): Map<*, *> {
        val file = File(requireNotNull(System.getProperty("carwece.graphicsWire")))
        check(file.isFile) { "Run flutter test --dart-define=EXPORT_GRAPHICS_WIRE=true test/graphics_channel_test.dart first" }
        val call = StandardMethodCodec.INSTANCE.decodeMethodCall(ByteBuffer.wrap(file.readBytes()))
        assertEquals("create", call.method)
        return call.arguments as Map<*, *>
    }
    private fun validate(args: Map<*, *>) {
        @Suppress("UNCHECKED_CAST")
        GraphicsContract.validateCreate(args["world"] as FloatArray,
            (args["objects"] as List<*>).map { it as FloatArray },
            args["shaders"] as List<String>, args["frame"] as FloatArray)
    }
    // Mesh indices derive from the roster exactly like Dart's GpuMeshId:
    // bodies, then pickup..damage, a damage block, wheels, then 12 effects.
    // objects.size == 3 * cars + 21, so the roster size is recoverable from
    // the payload itself and these tests survive roster growth.
    private fun rosterSize(objectCount: Int): Int {
        require((objectCount - 21) % 3 == 0) { "Unexpected object count: $objectCount" }
        return (objectCount - 21) / 3
    }
    @Test fun acceptsActualFlutterPayloadWithAllCarAndWheelModels() {
        val args = request()
        val count = (args["objects"] as List<*>).size
        val n = rosterSize(count)
        assertEquals(3 * n + 21, count)
        validate(args)
        val frame = args["frame"] as FloatArray
        val lastWheel = 3 * n + 8
        assertTrue((0 until frame[14].toInt()).any { frame[15 + it * 17].toInt() == lastWheel })
    }
    @Test fun wheelMaterialsAreOpaqueAndShieldSmokeAndIceUseBlending() {
        val meshes = request()["objects"] as List<*>
        val n = rosterSize(meshes.size)
        val wheel = 2 * n + 9
        for (i in wheel..wheel + n - 1) assertFalse(GraphicsContract.isTransparentMesh(meshes[i] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(meshes[n + 3] as FloatArray)) // shield
        assertTrue(GraphicsContract.isTransparentMesh(meshes[n + 7] as FloatArray)) // smoke
        assertTrue(GraphicsContract.isTransparentMesh(meshes[3 * n + 14] as FloatArray)) // frost
        assertFalse(GraphicsContract.isTransparentMesh(meshes[wheel - 1] as FloatArray))
    }
    @Test fun acceptsAdditionalEffectsWithinBudget() {
        val args = request().toMutableMap()
        val meshes = (args["objects"] as List<*>).toMutableList()
        repeat(5) { meshes.add(meshes.first()) }
        args["objects"] = meshes
        validate(args)
    }
    @Test fun refusesIncompleteMeshWithSpecificReason() {
        val args = request().toMutableMap()
        val meshes = (args["objects"] as List<*>).toMutableList()
        meshes[32] = FloatArray(35)
        args["objects"] = meshes
        val exception = assertThrows(IllegalArgumentException::class.java) { validate(args) }
        assertTrue(exception.message!!.contains("objeto 32"))
    }
    @Test fun refusesMissingMeshIndex() {
        val args = request().toMutableMap()
        val frame = (args["frame"] as FloatArray).copyOf()
        frame[15] = (args["objects"] as List<*>).size.toFloat(); args["frame"] = frame
        assertThrows(IllegalArgumentException::class.java) { validate(args) }
    }
    @Test fun refusesNonFiniteTransforms() {
        val args = request().toMutableMap()
        val frame = (args["frame"] as FloatArray).copyOf()
        frame[16] = Float.NaN; args["frame"] = frame
        assertThrows(IllegalArgumentException::class.java) { validate(args) }
    }
    @Test fun refusesTruncatedInstancePacket() {
        val args = request().toMutableMap()
        val frame = args["frame"] as FloatArray
        args["frame"] = frame.copyOf(frame.size - 1)
        assertThrows(IllegalArgumentException::class.java) { validate(args) }
    }
}
