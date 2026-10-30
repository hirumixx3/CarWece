package com.hirumisu.carwece

import java.io.File
import java.security.KeyFactory
import java.security.Signature
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import org.junit.Assert.*
import org.junit.Test

class HostIdentityTest {
    @Test fun ephemeralIdentityIsUniqueValidAndMatchesPrivateKey() {
        val first = HostIdentity.create()
        val second = HostIdentity.create()
        assertNotEquals(first["certificate"], second["certificate"])
        val cert = CertificateFactory.getInstance("X.509").generateCertificate(first.getValue("certificate").byteInputStream()) as X509Certificate
        cert.checkValidity()
        cert.verify(cert.publicKey)
        val raw = first.getValue("key").replace(Regex("-----[^-]+-----|\\s"), "")
        val key = KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(Base64.getDecoder().decode(raw)))
        val payload = "CarWece room interoperability".toByteArray()
        val signed = Signature.getInstance("SHA256withRSA").apply { initSign(key); update(payload) }.sign()
        assertTrue(Signature.getInstance("SHA256withRSA").apply { initVerify(cert); update(payload) }.verify(signed))
        val folder = File(File(requireNotNull(System.getProperty("carwece.graphicsWire"))).parentFile.parentFile, "host_identity").apply { mkdirs() }
        File(folder, "certificate.pem").writeText(first.getValue("certificate"))
        File(folder, "key.pem").writeText(first.getValue("key"))
    }
}
