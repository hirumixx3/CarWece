package com.hirumisu.carwece

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max

/** Production chunk/index/compact logic on desktop JVM. Not an Android RAM/FPS test.
 * Run with -Xmx128m -XX:MaxDirectMemorySize=32m. Also exports GPU-ready buffers. */
private fun readFloats(file: File): FloatArray {
    val data=FloatArray((file.length()/4).toInt())
    RandomAccessFile(file,"r").use { f ->
        val block=ByteBuffer.allocate(65536).order(ByteOrder.LITTLE_ENDIAN)
        var at=0
        while(at<data.size) {
            block.clear(); block.limit(minOf(block.capacity(),(data.size-at)*4))
            while(block.hasRemaining())check(f.channel.read(block)>0)
            block.flip(); val n=block.remaining()/4
            block.asFloatBuffer().get(data,at,n); at+=n
        }
    }
    return data
}
private fun digest(data: FloatArray): Long {
    var sum=0L
    for(i in data.indices step 36) {
        var hash=-3750763034362895579L
        for(k in 0 until 36) hash=(hash xor data[i+k].toRawBits().toLong())*1099511628211L
        sum+=hash
    }
    return sum
}
fun main(args: Array<String>) {
    val root=File(args[0]); val out=File(args[1]).also{it.mkdirs()}
    val selected=args.drop(2).toSet()
    val rows=ArrayList<String>()
    var scratch: ByteBuffer?=null
    val objectFiles=root.listFiles()!!.filter{it.name.startsWith("object_") && it.extension=="bin"}.sortedBy{it.name}
    // Retain a real full race's selected objects, as pendingObjects does on Android.
    val objects=objectFiles.map(::readFloats)
    fun export(name: String, data: FloatArray, world: Boolean) {
        var count=0; var vertices=0; var chunks=0; var largest=0; var gotDigest=0L
        val ranges=ArrayList<String>(); val index=ByteBuffer.allocate(65536).order(ByteOrder.LITTLE_ENDIAN)
        val vbo=RandomAccessFile(File(out,"$name.vbo"),"rw");vbo.setLength(0)
        val ibo=RandomAccessFile(File(out,"$name.ibo"),"rw");ibo.setLength(0)
        try {
            fun consume(block: FloatArray) {
                check(block.size%36==0)
                if(world)check(block.size<=RenderGeometry.MAX_CHUNK_TRIANGLES*36)
                gotDigest+=digest(block)
                val packed=RenderGeometry.index(block)
                // Indexing must not alter a single attribute of any vertex.
                for(i in packed.indices.indices)for(k in 0 until 12)
                    check(block[i*12+k].toRawBits()==packed.vertices[packed.indices[i]*12+k].toRawBits())
                val compact=RenderGeometry.compact(packed.vertices,scratch);scratch=compact
                while(compact.hasRemaining())vbo.channel.write(compact)
                for(n in packed.indices) {
                    if(index.remaining()<4) { index.flip();while(index.hasRemaining())ibo.channel.write(index);index.clear() }
                    index.putInt(n+vertices)
                }
                if(world)ranges.add("{\"first\":$count,\"count\":${packed.indices.size}}")
                count+=packed.indices.size;vertices+=packed.vertices.size/12;chunks++
                largest=max(largest,block.size*4)
            }
            if(world)RenderGeometry.forEachChunk(data,consume=::consume) else consume(data)
            index.flip();while(index.hasRemaining())ibo.channel.write(index)
        } finally {vbo.close();ibo.close()}
        check(count==data.size/12 && gotDigest==digest(data)) { "Triangles changed: $name" }
        val gpu=File(out,"$name.vbo").length()+File(out,"$name.ibo").length()
        rows.add("\"$name\":{\"originalBytes\":${data.size*4},\"gpuBytes\":$gpu,\"vertices\":$vertices,\"count\":$count,\"transparent\":${GraphicsContract.isTransparentMesh(data)},\"shadow\":${GraphicsContract.castsShadowMesh(data)},\"ranges\":[${ranges.joinToString(",")}],\"chunks\":$chunks,\"maxChunkBytes\":$largest}")
        println("PASS $name triangles=${count/3} chunks=$chunks largestTemporaryBlock=$largest heapLimit=${Runtime.getRuntime().maxMemory()} objectsBytes=${objects.sumOf{it.size.toLong()*4}}")
    }
    for((i,file) in objectFiles.withIndex())export(file.nameWithoutExtension,objects[i],false)
    for(file in root.listFiles()!!.filter{it.extension=="bin" && !it.name.startsWith("object_")}.sortedBy{it.name}) {
        if(selected.isNotEmpty() && file.nameWithoutExtension !in selected)continue
        export(file.nameWithoutExtension,readFloats(file),true)
    }
    File(out,"optimized.json").writeText("{\"scope\":\"Bounded production geometry on desktop JVM, not Android device validation\",\"meshes\":{${rows.joinToString(",")}},\"frames\":[]}")
}
