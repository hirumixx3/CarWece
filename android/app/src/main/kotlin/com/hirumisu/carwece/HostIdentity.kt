package com.hirumisu.carwece

import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.SecureRandom
import java.security.Signature
import java.security.cert.CertificateFactory
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Ephemeral RFC 5280 certificate. Unique keys per room; no bundled secrets. */
object HostIdentity {
    private fun der(tag: Int, bytes: ByteArray): ByteArray {
        val size = bytes.size
        val length = if (size < 128) byteArrayOf(size.toByte()) else {
            val raw = BigInteger.valueOf(size.toLong()).toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
            byteArrayOf((0x80 or raw.size).toByte()) + raw
        }
        return byteArrayOf(tag.toByte()) + length + bytes
    }
    private fun seq(vararg fields: ByteArray) = der(0x30, fields.fold(byteArrayOf()) { a, b -> a + b })
    private fun integer(n: BigInteger) = der(2, n.toByteArray())
    private fun pem(label: String, bytes: ByteArray): String {
        // Android 7 (API 24/25) has no java.util.Base64.
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        val text = StringBuilder()
        for (i in bytes.indices step 3) {
            val a = bytes[i].toInt() and 255
            val b = if (i + 1 < bytes.size) bytes[i + 1].toInt() and 255 else 0
            val c = if (i + 2 < bytes.size) bytes[i + 2].toInt() and 255 else 0
            text.append(alphabet[a shr 2]).append(alphabet[((a and 3) shl 4) or (b shr 4)])
                .append(if (i + 1 < bytes.size) alphabet[((b and 15) shl 2) or (c shr 6)] else '=')
                .append(if (i + 2 < bytes.size) alphabet[c and 63] else '=')
        }
        return "-----BEGIN $label-----\n" + text.toString().chunked(64).joinToString("\n") + "\n-----END $label-----\n"
    }

    fun create(): Map<String, String> {
        val random = SecureRandom()
        val keys = KeyPairGenerator.getInstance("RSA").apply { initialize(2048, random) }.generateKeyPair()
        // sha256WithRSAEncryption 1.2.840.113549.1.1.11, NULL parameters.
        val algorithm = seq(der(6, byteArrayOf(0x2a, 0x86.toByte(), 0x48, 0x86.toByte(), 0xf7.toByte(), 0x0d, 1, 1, 11)), der(5, byteArrayOf()))
        val commonName = seq(der(6, byteArrayOf(0x55, 4, 3)), der(12, "CarWece friend room".toByteArray(Charsets.UTF_8)))
        val name = seq(der(0x31, commonName))
        val format = SimpleDateFormat("yyMMddHHmmss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val now = System.currentTimeMillis()
        fun utc(time: Long) = der(23, format.format(Date(time)).toByteArray(Charsets.US_ASCII))
        val validity = seq(utc(now - 86400000L), utc(now + 7 * 86400000L))
        val tbs = seq(der(0xa0, integer(BigInteger.valueOf(2))),
            integer(BigInteger(128, random).setBit(127)), algorithm, name, validity, name, keys.public.encoded)
        val signed = Signature.getInstance("SHA256withRSA").apply { initSign(keys.private, random); update(tbs) }.sign()
        val certificate = seq(tbs, algorithm, der(3, byteArrayOf(0) + signed))
        // Parse and verify before returning bytes to the Dart TLS listener.
        CertificateFactory.getInstance("X.509").generateCertificate(certificate.inputStream()).verify(keys.public)
        return mapOf("certificate" to pem("CERTIFICATE", certificate), "key" to pem("PRIVATE KEY", keys.private.encoded))
    }
}
