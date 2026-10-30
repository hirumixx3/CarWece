package com.hirumisu.carwece

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Desktop JVM exercise of the actual production geometry code, not device RAM/FPS. */
fun main(args: Array<String>) {
    val root=File(args[0]);val out=File(args[1]).also{it.mkdirs()}
    data class Info(val count:Int,val bounds:RenderGeometry.Bounds,val ranges:List<RenderGeometry.Range>,
                    val transparent:Boolean,val shadow:Boolean)
    val infos=HashMap<String,Info>();val rows=ArrayList<String>()
    var oldBytes=0L;var newBytes=0L
    for(file in root.listFiles()!!.filter{it.extension=="bin"}.sortedBy{it.name}) {
        val raw=file.readBytes();val floats=FloatArray(raw.size/4)
        ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer().get(floats)
        val name=file.nameWithoutExtension
        val chunks=if(name.startsWith("object_"))null else RenderGeometry.partition(floats)
        val source=chunks?.vertices?:floats
        val indexed=RenderGeometry.index(source);val compact=RenderGeometry.compact(indexed.vertices)
        val bytes=ByteArray(compact.remaining());compact.get(bytes)
        File(out,"$name.vbo").writeBytes(bytes)
        val indices=ByteBuffer.allocate(indexed.indices.size*4).order(ByteOrder.LITTLE_ENDIAN)
        indices.asIntBuffer().put(indexed.indices);File(out,"$name.ibo").writeBytes(indices.array())
        val ranges=chunks?.ranges?:emptyList()
        val transparent=GraphicsContract.isTransparentMesh(floats)
        val shadow=GraphicsContract.castsShadowMesh(floats)
        infos[name]=Info(indexed.indices.size,RenderGeometry.Bounds.of(floats),ranges,transparent,shadow)
        val rangesJson=ranges.joinToString(","){r->
            "{\"first\":${r.first},\"count\":${r.count}}"
        }
        val total=bytes.size+indices.capacity();oldBytes+=raw.size;newBytes+=total
        rows.add("\"$name\":{\"originalBytes\":${raw.size},\"gpuBytes\":$total,\"vertices\":${indexed.vertices.size/12},\"count\":${indexed.indices.size},\"transparent\":$transparent,\"shadow\":$shadow,\"ranges\":[$rangesJson]}")
    }
    val frames=ArrayList<String>()
    for(line in File(root,"probe_frames.txt").readLines()) {
        val columns=line.split('|');val name=columns[0];val w=infos.getValue(columns[1])
        val camera=RenderGeometry.Frustum().also{it.set(columns[2].split(',').map(String::toFloat).toFloatArray())}
        val light=RenderGeometry.Frustum().also{it.set(columns[3].split(',').map(String::toFloat).toFloatArray())}
        val visible=w.ranges.indices.filter{camera.visible(w.ranges[it].bounds)}
        val shadows=w.ranges.indices.filter{light.visible(w.ranges[it].bounds)}
        val visibleInstances=ArrayList<Int>();val shadowInstances=ArrayList<Int>()
        var oldScene=w.count;var oldShadow=w.count
        var newScene=visible.sumOf{w.ranges[it].count};var newShadow=shadows.sumOf{w.ranges[it].count}
        for(i in 4 until columns.size) {
            val values=columns[i].split(',');val mesh=infos.getValue("object_${values[0]}")
            val model=values.drop(1).map(String::toFloat).toFloatArray()
            oldScene+=mesh.count
            if(camera.visible(mesh.bounds,model)){visibleInstances.add(i-4);newScene+=mesh.count}
            if(!mesh.transparent && mesh.shadow) {
                oldShadow+=mesh.count
                if(light.visible(mesh.bounds,model)){shadowInstances.add(i-4);newShadow+=mesh.count}
            }
        }
        frames.add("{\"name\":\"$name\",\"visibleWorld\":$visible,\"shadowWorld\":$shadows,\"visibleInstances\":$visibleInstances,\"shadowInstances\":$shadowInstances,\"oldSceneTriangles\":${oldScene/3},\"newSceneTriangles\":${newScene/3},\"oldShadowTriangles\":${oldShadow/3},\"newShadowTriangles\":${newShadow/3}}")
    }
    val json="{\"scope\":\"Production Kotlin geometry on desktop JVM; GPU buffer sizes, not Android RAM or FPS\",\"originalBytes\":$oldBytes,\"gpuBytes\":$newBytes,\"meshes\":{${rows.joinToString(",")}},\"frames\":[${frames.joinToString(",")}] }"
    File(out,"optimized.json").writeText(json)
    println("${infos.size} meshes, ${frames.size} frames, GPU buffer bytes $oldBytes -> $newBytes")
}
