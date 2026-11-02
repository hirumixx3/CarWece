package com.hirumisu.carwece

/** Validates the typed payload at the real Flutter/Android boundary, before EGL. */
internal object GraphicsContract {
    // 81 cars × (body, damage, wheels) + 21 effects + 60 battle meshes = 324.
    // Only active car slots contain full geometry; unused slots stay tiny.
    const val MAX_MESHES = 512
    const val MAX_INSTANCES = 128

    fun validateCreate(world: FloatArray, meshes: List<FloatArray>, shaders: List<String>, frame: FloatArray) {
        require(meshes.isNotEmpty() && meshes.size <= MAX_MESHES) {
            "Quantidade de modelos inválida: ${meshes.size} (máximo $MAX_MESHES)"
        }
        require(shaders.size == 4 && shaders.all { it.isNotBlank() }) { "Shaders incompletos" }
        validateMesh(world, "cenário")
        meshes.forEachIndexed { i, mesh -> validateMesh(mesh, "objeto $i") }
        validateFrame(frame, meshes.size)
    }

    /** Render state follows materials, never the position in the model list. */
    fun isTransparentMesh(data: FloatArray): Boolean =
        (11 until data.size step 12).any { data[it].toInt() == 11 || data[it].toInt() == 12 || data[it].toInt() == 17 }

    fun castsShadowMesh(data: FloatArray): Boolean =
        (11 until data.size step 12).any { val m=data[it].toInt(); m!=11 && m!=12 && m!=17 && m!=18 }

    private fun validateMesh(data: FloatArray, label: String) {
        require(data.isNotEmpty() && data.size % 36 == 0 && data.all { it.isFinite() }) {
            "Malha inválida: $label"
        }
    }

    fun validateFrame(data: FloatArray, meshCount: Int) {
        require(data.size >= 15 && data.all { it.isFinite() }) { "Quadro incompleto" }
        val count = data[14].toInt()
        require(data[14] == count.toFloat() && count in 0..MAX_INSTANCES && data.size == 15 + count * 17) {
            "Quantidade de instâncias inválida"
        }
        for (i in 0 until count) {
            val mesh = data[15 + i * 17]
            require(mesh == mesh.toInt().toFloat() && mesh.toInt() in 0 until meshCount) {
                "Modelo ausente: $mesh"
            }
        }
    }
}
