package com.hirumisu.carwece

import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class BattleGraphicsContractTest {
    private fun request(): Map<*, *> {
        val file = File(requireNotNull(System.getProperty("carwece.battleWire")))
        check(file.isFile) { "Run flutter test --dart-define=EXPORT_GRAPHICS_WIRE=true first" }
        val call = StandardMethodCodec.INSTANCE.decodeMethodCall(ByteBuffer.wrap(file.readBytes()))
        assertEquals("create", call.method)
        return call.arguments as Map<*, *>
    }
    private fun validate(a: Map<*, *>) {
        GraphicsContract.validateCreate(a["world"] as FloatArray,
            (a["objects"] as List<*>).map { it as FloatArray },
            a["shaders"] as List<String>,a["frame"] as FloatArray)
    }
    @Test fun acceptsActualBattleWorldAndAllFortyFourWeaponAttachments() {
        val a=request();assertEquals(249,(a["objects"] as List<*>).size);validate(a)
    }
    @Test fun healthBarsTurretsAndProjectilesAreInTheActualFrame() {
        val a=request();val f=a["frame"] as FloatArray
        val indices=(0 until f[14].toInt()).map { f[15+it*17].toInt() }
        assertTrue(indices.contains(196));assertTrue(indices.contains(198));assertTrue(indices.contains(221))
        assertTrue(indices.contains(190));assertTrue(f[14]<=GraphicsContract.MAX_INSTANCES)
    }
    @Test fun healthAndMetalAreOpaqueWhileGasUsesTransparentMaterial() {
        val m=request()["objects"] as List<*>
        for(i in listOf(189,190,191,192,193,196,197,198,199,200,203))
            assertFalse(GraphicsContract.isTransparentMesh(m[i] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(m[202] as FloatArray))
    }
    @Test fun everyAdditionalVertexAndTransformHasFiniteValues() {
        val a=request();val meshes=a["objects"] as List<*>
        for(i in 189..247) {
            val m=meshes[i] as FloatArray;assertTrue(m.isNotEmpty());assertEquals(0,m.size%36)
            assertTrue(m.all { it.isFinite() })
        }
        assertTrue((a["frame"] as FloatArray).all { it.isFinite() })
    }
    @Test fun battleFrameRejectsAnIndexOutsideTheUploadedInventory() {
        val a=request().toMutableMap();val frame=(a["frame"] as FloatArray).clone();frame[15]=(a["objects"] as List<*>).size.toFloat();a["frame"]=frame
        try {validate(a);fail("Invalid battle mesh accepted")}catch(_:IllegalArgumentException){}
    }
    @Test fun healthBillboardsNeverCastFloatingRectangularShadows() {
        val meshes=request()["objects"] as List<*>
        for(i in 196..198)assertFalse(GraphicsContract.castsShadowMesh(meshes[i] as FloatArray))
        assertTrue(GraphicsContract.castsShadowMesh(meshes[203] as FloatArray))
    }
}
