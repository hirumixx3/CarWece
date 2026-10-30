package com.hirumisu.carwece

import org.junit.Assert.*
import org.junit.Test

class RenderOptimizationTest {
    private val identity=floatArrayOf(1f,0f,0f,0f,0f,1f,0f,0f,0f,0f,1f,0f,0f,0f,0f,1f)
    private fun vertex(x: Float,y: Float,z: Float,material: Float=3f)=
        floatArrayOf(x,y,z,.123456f,.98765f,-.095f,.2f,.4f,.6f,2.5f,-4.25f,material)
    private fun quad()=vertex(0f,0f,0f)+vertex(1f,0f,0f)+vertex(1f,1f,0f)+
        vertex(0f,0f,0f)+vertex(1f,1f,0f)+vertex(0f,1f,0f)
    @Test fun indexedMeshReconstructsEveryOriginalAttributeBitExactly() {
        val data=quad();val p=RenderGeometry.index(data)
        assertEquals(4*12,p.vertices.size);assertEquals(6,p.indices.size)
        for(i in p.indices.indices)for(k in 0..11)
            assertEquals(data[i*12+k].toRawBits(),p.vertices[p.indices[i]*12+k].toRawBits())
    }
    @Test fun materialAndNormalsNeverMergeAtSharedPositions() {
        val data=quad()+vertex(0f,0f,0f,4f)+vertex(1f,0f,0f,4f)+vertex(1f,1f,0f,4f)
        assertEquals(7*12,RenderGeometry.index(data).vertices.size)
    }
    @Test fun compactLayoutKeepsPositionsUvsAndMaterialsWithBoundedNormalError() {
        val data=quad();val b=RenderGeometry.compact(data)
        assertEquals(6*32,b.remaining())
        for(i in 0 until 6) {
            val at=i*32;val s=i*12
            for(k in 0..2)assertEquals(data[s+k],b.getFloat(at+k*4),0f)
            for(k in 0..2)assertEquals(data[s+3+k],b.getShort(at+12+k*2)/32767f,1f/32767)
            for(k in 0..2)assertEquals(data[s+6+k],(b.get(at+18+k).toInt() and 255)/255f,1f/255)
            assertEquals(data[s+11].toInt(),b.get(at+21).toInt() and 255)
            assertEquals(data[s+9],b.getFloat(at+24),0f);assertEquals(data[s+10],b.getFloat(at+28),0f)
        }
    }
    @Test fun partitionKeepsAllTrianglesIncludingNegativeAndLargeSpanningGeometry() {
        val data=quad()+vertex(-420f,0f,-510f)+vertex(430f,0f,-510f)+vertex(0f,0f,510f)
        val p=RenderGeometry.partition(data,1f)
        assertEquals(data.size,p.vertices.size)
        fun triangles(v:FloatArray)=(v.indices step 36).map { i->
            (i until i+36).map{v[it].toRawBits()}
        }.groupingBy{it}.eachCount()
        assertEquals(triangles(data),triangles(p.vertices))
        assertEquals(data.size/12,p.ranges.sumOf{it.count})
        for(r in p.ranges)for(i in r.first*12 until (r.first+r.count)*12 step 12) {
            assertTrue(kotlin.math.abs(p.vertices[i]-r.bounds.x)<=r.bounds.rx)
            assertTrue(kotlin.math.abs(p.vertices[i+1]-r.bounds.y)<=r.bounds.ry)
            assertTrue(kotlin.math.abs(p.vertices[i+2]-r.bounds.z)<=r.bounds.rz)
        }
    }
    @Test fun frustumConservativelyKeepsCrossingGeometryAndRejectsAllSixOutsidePlanes() {
        val f=RenderGeometry.Frustum(); f.set(identity)
        assertTrue(f.visible(RenderGeometry.Bounds(0f,0f,0f,.2f,.2f,.2f)))
        assertTrue(f.visible(RenderGeometry.Bounds(2f,0f,0f,1.01f,.2f,.2f)))
        for(axis in 0..2)for(sign in listOf(-1f,1f)) {
            val p=FloatArray(3);p[axis]=sign*2
            assertFalse(f.visible(RenderGeometry.Bounds(p[0],p[1],p[2],.1f,.1f,.1f)))
        }
    }
    @Test fun frustumHandlesMirroringRotationNonuniformScaleAndTranslation() {
        val f=RenderGeometry.Frustum();f.set(identity)
        val b=RenderGeometry.Bounds(3f,0f,0f,.1f,.2f,.3f)
        val m=identity.copyOf();m[0]=-.5f;m[12]=1.5f
        assertTrue(f.visible(b,m))
        m[12]=8f;assertFalse(f.visible(b,m))
        val turn=floatArrayOf(0f,0f,2f,0f,0f,.5f,0f,0f,-1f,0f,0f,0f,0f,0f,-6f,1f)
        assertTrue(f.visible(b,turn))
    }
    @Test fun costSpikesAndInvalidSamplesDoNotDropQuality() {
        val b=RenderBudget();repeat(50){b.sample(16.0)}
        b.sample(100.0);b.sample(Double.NaN);b.sample(300.0);repeat(50){b.sample(16.0)}
        assertEquals(2,b.level)
    }
    @Test fun sustainedLoadReducesResolutionAndCannotGoBelowItsFloor() {
        val b=RenderBudget();repeat(800){b.sample(40.0)}
        assertEquals(0,b.level);assertEquals(.55f,b.scale,0f)
    }
    @Test fun recoveryIsSlowAndPauseResetsTheObservationWindow() {
        val b=RenderBudget();repeat(200){b.sample(40.0)}
        val level=b.level;b.reset();repeat(100){b.sample(16.0)}
        assertEquals(level,b.level);repeat(600){b.sample(16.0)}
        assertTrue(b.level>level)
    }
}
