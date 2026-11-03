package com.hirumisu.carwece

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

/** Pure geometry preparation, shared by the renderer and JVM regression tests.
 * No simplification: every triangle and position is kept. */
internal object RenderGeometry {
    data class Bounds(val x: Float, val y: Float, val z: Float,
                      val rx: Float, val ry: Float, val rz: Float) {
        companion object {
            fun of(data: FloatArray, first: Int = 0, end: Int = data.size): Bounds {
                var ax=Float.POSITIVE_INFINITY; var ay=ax; var az=ax
                var bx=Float.NEGATIVE_INFINITY; var by=bx; var bz=bx
                for (i in first until end step 12) {
                    ax=min(ax,data[i]); ay=min(ay,data[i+1]); az=min(az,data[i+2])
                    bx=max(bx,data[i]); by=max(by,data[i+1]); bz=max(bz,data[i+2])
                }
                return Bounds((ax+bx)*.5f,(ay+by)*.5f,(az+bz)*.5f,
                    (bx-ax)*.5f+.01f,(by-ay)*.5f+.01f,(bz-az)*.5f+.01f)
            }
        }
    }
    data class Range(val first: Int, val count: Int, val bounds: Bounds)
    data class Chunks(val vertices: FloatArray, val ranges: List<Range>)
    private class TriangleList {
        var values=IntArray(32); var size=0
        fun add(i: Int) { if(size==values.size)values=values.copyOf(size*2); values[size++]=i }
    }
    // Bound temporary allocations even when one room/cell contains most of a mesh.
    const val MAX_CHUNK_TRIANGLES = 4096

    private fun cells(data: FloatArray, cell: Float): LinkedHashMap<Long,TriangleList> {
        require(data.isNotEmpty() && data.size%36==0 && cell.isFinite() && cell>0)
        val cells=LinkedHashMap<Long,TriangleList>()
        for(i in data.indices step 36) {
            val x=floor((data[i]+data[i+12]+data[i+24])/3/cell).toInt()
            val z=floor((data[i+2]+data[i+14]+data[i+26])/3/cell).toInt()
            val key=(x.toLong() shl 32) xor (z.toLong() and 0xffffffffL)
            cells.getOrPut(key){TriangleList()}.add(i)
        }
        return cells
    }

    /** Upload one bounded spatial block at a time. No full-world packed/unique copy.
     * Every original triangle is delivered once, with bit-exact attributes/winding.
     * Consumer must upload synchronously, not retain the temporary blocks. */
    fun forEachChunk(data: FloatArray, cell: Float = 160f,
                     maxTriangles: Int = MAX_CHUNK_TRIANGLES,
                     consume: (FloatArray) -> Unit) {
        require(maxTriangles in 1..MAX_CHUNK_TRIANGLES)
        for (list in cells(data,cell).values) {
            var start=0
            while(start<list.size) {
                val count=minOf(maxTriangles,list.size-start)
                val block=FloatArray(count*36)
                for(j in 0 until count) {
                    val from=list.values[start+j]
                    data.copyInto(block,j*36,from,from+36)
                }
                consume(block)
                start+=count
            }
        }
    }

    // Reference/export API; Android runtime uses forEachChunk instead.
    fun partition(data: FloatArray, cell: Float = 160f): Chunks {
        val cells=cells(data,cell)
        val packed=FloatArray(data.size); val ranges=ArrayList<Range>(cells.size)
        var cursor=0
        for(list in cells.values) {
            val start=cursor
            for(j in 0 until list.size) {
                data.copyInto(packed,cursor,list.values[j],list.values[j]+36); cursor+=36
            }
            ranges.add(Range(start/12,(cursor-start)/12,Bounds.of(packed,start,cursor)))
        }
        return Chunks(packed,ranges)
    }

    data class Indexed(val vertices: FloatArray, val indices: IntArray)
    /** Open-addressed, bit-exact deduplication avoids per-vertex object allocation. */
    fun index(data: FloatArray): Indexed {
        require(data.isNotEmpty() && data.size%36==0)
        val count=data.size/12
        var slots=1; while(slots<count*2)slots=slots shl 1
        val table=IntArray(slots); val unique=FloatArray(data.size); val indices=IntArray(count)
        var used=0
        for(v in 0 until count) {
            val from=v*12; var hash=0x811c9dc5.toInt()
            for(k in 0 until 12)hash=(hash xor data[from+k].toRawBits())*16777619
            var slot=hash and (slots-1)
            while(true) {
                val existing=table[slot]-1
                if(existing<0) {
                    data.copyInto(unique,used*12,from,from+12)
                    table[slot]=used+1; indices[v]=used++; break
                }
                var equal=true
                for(k in 0 until 12)if(unique[existing*12+k].toRawBits()!=data[from+k].toRawBits()) { equal=false; break }
                if(equal) { indices[v]=existing; break }
                slot=(slot+1) and (slots-1)
            }
        }
        return Indexed(unique.copyOf(used*12),indices)
    }

    /** 32-byte mobile vertex: float position/UV, signed-normalized normal,
     * normalized RGB8 and integer material. Bounds/physics use original floats. */
    fun compact(data: FloatArray, reuse: ByteBuffer? = null): ByteBuffer {
        require(data.size%12==0)
        val length=data.size/12*32
        val bytes=(reuse?.takeIf { it.isDirect && it.capacity()>=length }
            ?: ByteBuffer.allocateDirect(length)).order(ByteOrder.nativeOrder())
        bytes.clear(); bytes.limit(length)
        for(i in data.indices step 12) {
            bytes.putFloat(data[i]); bytes.putFloat(data[i+1]); bytes.putFloat(data[i+2])
            for(k in 3..5)bytes.putShort((data[i+k].coerceIn(-1f,1f)*32767).roundToInt().toShort())
            for(k in 6..8)bytes.put((data[i+k].coerceIn(0f,1f)*255).roundToInt().toByte())
            bytes.put(data[i+11].roundToInt().toByte()); bytes.putShort(0)
            bytes.putFloat(data[i+9]); bytes.putFloat(data[i+10])
        }
        bytes.position(0)
        return bytes
    }

    /** Column-major OpenGL clip planes. Conservative AABB test, including
     * transformed objects, nonuniform scale and geometry crossing a cell edge. */
    class Frustum {
        private val planes=FloatArray(24)
        fun set(m: FloatArray) {
            for(axis in 0..2)for(side in 0..1) {
                val sign=if(side==0)1f else -1f; val p=(axis*2+side)*4
                for(k in 0..3)planes[p+k]=m[k*4+3]+sign*m[k*4+axis]
            }
        }
        fun visible(b: Bounds, model: FloatArray? = null, offset: Int = 0): Boolean {
            var x=b.x; var y=b.y; var z=b.z; var rx=b.rx; var ry=b.ry; var rz=b.rz
            if(model!=null) {
                x=model[offset]*b.x+model[offset+4]*b.y+model[offset+8]*b.z+model[offset+12]
                y=model[offset+1]*b.x+model[offset+5]*b.y+model[offset+9]*b.z+model[offset+13]
                z=model[offset+2]*b.x+model[offset+6]*b.y+model[offset+10]*b.z+model[offset+14]
                rx=abs(model[offset])*b.rx+abs(model[offset+4])*b.ry+abs(model[offset+8])*b.rz
                ry=abs(model[offset+1])*b.rx+abs(model[offset+5])*b.ry+abs(model[offset+9])*b.rz
                rz=abs(model[offset+2])*b.rx+abs(model[offset+6])*b.ry+abs(model[offset+10])*b.rz
            }
            for(p in planes.indices step 4) {
                if(planes[p]*x+planes[p+1]*y+planes[p+2]*z+planes[p+3]+
                    abs(planes[p])*rx+abs(planes[p+1])*ry+abs(planes[p+2])*rz < 0f)return false
            }
            return true
        }
    }
}
