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
    // Battle meshes are appended after the race inventory (3 * cars + 21),
    // so their base index follows the roster size in the payload itself.
    private fun battleBase(objectCount: Int): Int {
        require((objectCount - 60 - 21) % 3 == 0) { "Unexpected object count: $objectCount" }
        return objectCount - 60
    }
    @Test fun acceptsActualBattleWorldAndAllFortyFourWeaponAttachments() {
        val a=request();val count=(a["objects"] as List<*>).size
        assertEquals(battleBase(count) + 60, count);validate(a)
    }
    @Test fun healthBarsTurretsAndProjectilesAreInTheActualFrame() {
        val a=request();val f=a["frame"] as FloatArray
        val base=battleBase((a["objects"] as List<*>).size)
        val indices=(0 until f[14].toInt()).map { f[15+it*17].toInt() }
        assertTrue(indices.contains(base+7));assertTrue(indices.contains(base+9));assertTrue(indices.contains(base+32))
        assertTrue(indices.contains(base+1));assertTrue(f[14]<=GraphicsContract.MAX_INSTANCES)
    }
    @Test fun healthAndMetalAreOpaqueWhileGasUsesTransparentMaterial() {
        val m=request()["objects"] as List<*>
        val base=battleBase(m.size)
        for(i in listOf(0,1,2,3,4,7,8,9,10,11,14))
            assertFalse(GraphicsContract.isTransparentMesh(m[base+i] as FloatArray))
        assertTrue(GraphicsContract.isTransparentMesh(m[base+13] as FloatArray))
    }
    @Test fun everyAdditionalVertexAndTransformHasFiniteValues() {
        val a=request();val meshes=a["objects"] as List<*>
        val base=battleBase(meshes.size)
        for(i in base..base+58) {
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
        val base=battleBase(meshes.size)
        for(i in base+7..base+9)assertFalse(GraphicsContract.castsShadowMesh(meshes[i] as FloatArray))
        assertTrue(GraphicsContract.castsShadowMesh(meshes[base+14] as FloatArray))
    }
}
