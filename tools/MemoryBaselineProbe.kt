package com.hirumisu.carwece
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

// Same geometry functions as old Android initGeometry/upload, under a small JVM heap.
// This is NOT a measurement of the Android app's RSS or GPU performance.
private fun readMesh(file: File): FloatArray {
    val data = FloatArray((file.length()/4).toInt())
    RandomAccessFile(file,"r").use { f ->
        val bytes=ByteBuffer.allocate(64*1024).order(ByteOrder.LITTLE_ENDIAN)
        var at=0
        while(at<data.size) {
            bytes.clear(); bytes.limit(minOf(bytes.capacity(),(data.size-at)*4))
            while(bytes.hasRemaining()) check(f.channel.read(bytes)>0)
            bytes.flip(); val n=bytes.remaining()/4
            bytes.asFloatBuffer().get(data,at,n); at+=n
        }
    }
    return data
}
fun main(args: Array<String>) {
    val root=File(args[0]); val id=args[1]
    // Retain actual six-car payload alongside the world, as in the real constructor.
    val objects=root.listFiles()!!.filter{it.name.startsWith("object_")}.map(::readMesh)
    val source=readMesh(File(root,"$id.bin"))
    val chunks=RenderGeometry.partition(source)
    val packed=RenderGeometry.index(chunks.vertices)
    val gpu=RenderGeometry.compact(packed.vertices)
    println("PASS $id floats=${source.size} indices=${packed.indices.size} gpuBytes=${gpu.remaining()} objectsBytes=${objects.sumOf{it.size.toLong()*4}}")
}
