package com.hirumisu.carwece

import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer

class RenderMemoryRegressionTest {
    private fun triangle(x: Float, z: Float): FloatArray = floatArrayOf(
        x,0f,z, 0f,1f,0f, 1f,.5f,0f, 0f,0f,7f,
        x+1,0f,z, 0f,1f,0f, 1f,.5f,0f, 1f,0f,7f,
        x,0f,z+1, 0f,1f,0f, 1f,.5f,0f, 0f,1f,7f)

    @Test fun streamingMatchesReferencePartitionBitExactlyAcrossCells() {
        val data=triangle(-500f,-500f)+triangle(900f,0f)+triangle(-501f,-502f)+triangle(0f,0f)
        val expected=RenderGeometry.partition(data).vertices
        val actual=ArrayList<Float>()
        RenderGeometry.forEachChunk(data,maxTriangles=1) { actual.addAll(it.toList()) }
        assertArrayEquals(expected,actual.toFloatArray(),0f)
    }
    @Test fun aDenseSingleCellCannotExceedTheFixedTemporaryBudget() {
        val t=triangle(1f,1f)
        val count=RenderGeometry.MAX_CHUNK_TRIANGLES*3+1
        val data=FloatArray(count*36){t[it%36]}
        var triangles=0;var blocks=0
        RenderGeometry.forEachChunk(data) {
            assertTrue(it.size<=4096*36)
            assertEquals(0,it.size%36)
            for(i in it.indices)assertEquals(t[i%36].toRawBits(),it[i].toRawBits())
            triangles+=it.size/36;blocks++
        }
        assertEquals(count,triangles);assertEquals(4,blocks)
    }
    @Test fun eachChunkBoundsContainAllVerticesIncludingSpanningTriangles() {
        val data=triangle(-550f,700f)+triangle(500f,-800f)
        RenderGeometry.forEachChunk(data,maxTriangles=1) { block ->
            val b=RenderGeometry.Bounds.of(block)
            for(i in block.indices step 12) {
                assertTrue(kotlin.math.abs(block[i]-b.x)<=b.rx)
                assertTrue(kotlin.math.abs(block[i+1]-b.y)<=b.ry)
                assertTrue(kotlin.math.abs(block[i+2]-b.z)<=b.rz)
            }
        }
    }
    @Test fun reusedDirectBufferHasExactUploadLimitAndNoStaleTail() {
        val t=triangle(0f,0f)
        val large=RenderGeometry.compact(t+t+t)
        val small=RenderGeometry.compact(t,large)
        assertSame(large,small);assertEquals(3*32,small.remaining())
        assertArrayEquals(bytes(RenderGeometry.compact(t)),bytes(small))
    }
    private fun bytes(b: ByteBuffer)=ByteArray(b.remaining()).also { b.get(it) }
    @Test fun rejectsInvalidChunkSizesAndCellWidths() {
        val t=triangle(0f,0f)
        for(n in listOf(0,-1,4097)) {
            try { RenderGeometry.forEachChunk(t,maxTriangles=n) {}; fail("accepted $n") }
            catch(_:IllegalArgumentException) {}
        }
        for(cell in listOf(0f,-1f,Float.NaN,Float.POSITIVE_INFINITY)) {
            try { RenderGeometry.forEachChunk(t,cell=cell) {}; fail("accepted $cell") }
            catch(_:IllegalArgumentException) {}
        }
    }
    @Test fun cancellationStopsBeforePreparingFurtherBlocks() {
        var blocks=0
        try {
            RenderGeometry.forEachChunk(triangle(0f,0f)+triangle(500f,500f)) {
                blocks++;throw InterruptedException()
            }
            fail("cancellation swallowed")
        } catch(_:InterruptedException) { assertEquals(1,blocks) }
    }
}
