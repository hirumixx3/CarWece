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
    @Test fun acceptsActualFlutterPayloadWithAllCarAndWheelModels() {
        val args = request()
        assertEquals(114, (args["objects"] as List<*>).size)
        validate(args)
        val frame = args["frame"] as FloatArray
        assertTrue((0 until frame[14].toInt()).any { frame[15 + it * 17].toInt() == 101 })
    }
    @Test fun wheelMaterialsAreOpaqueAndShieldSmokeAndIceUseBlending() {
        val meshes = request()["objects"] as List<*>
        for (i in 71..101) assertFalse(GraphicsContract.isTransparentMesh(meshes[i] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(meshes[34] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(meshes[38] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(meshes[107] as FloatArray))
        assertFalse(GraphicsContract.isTransparentMesh(meshes[70] as FloatArray))
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
