package com.example.firmador_movil

// IMPORTANTE: Aquí cambiamos FlutterActivity por FlutterFragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.cert.X509Certificate

// IMPORTANTE: Aquí heredamos de FlutterFragmentActivity
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.csice.firmador/crypto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                val path = call.argument<String>("path")
                val password = call.argument<String>("password")
                
                if (path == null || password == null) {
                    result.error("ARGS_ERROR", "La ruta o la contraseña están vacías", null)
                    return@setMethodCallHandler
                }

                val ks = KeyStore.getInstance("PKCS12")
                ks.load(FileInputStream(path), password.toCharArray())
                
                val aliases = ks.aliases()
                if (!aliases.hasMoreElements()) {
                    result.error("KEY_ERROR", "El archivo .p12 no contiene llaves", null)
                    return@setMethodCallHandler
                }
                val alias = aliases.nextElement()

                if (call.method == "getCertInfo") {
                    val cert = ks.getCertificate(alias) as X509Certificate
                    val certChain = ks.getCertificateChain(alias) ?: arrayOf(cert)
                    val certList = certChain.map { it.encoded }

                    // ¡NUEVO!: Extraemos el número de serie real y lo formateamos con ":"
                    val serialHexStr = cert.serialNumber.toString(16).uppercase()
                    val paddedSerial = if (serialHexStr.length % 2 != 0) "0$serialHexStr" else serialHexStr
                    val serialFormat = paddedSerial.chunked(2).joinToString(":")

                    result.success(mapOf(
                        "subject" to cert.subjectX500Principal.name, // Usamos formato estándar
                        "serial" to serialFormat, // Mandamos el serial real a Flutter
                        "chain" to certList
                    ))
                } else if (call.method == "signECDSA") {
                    val data = call.argument<ByteArray>("data")
                    val privateKey = ks.getKey(alias, password.toCharArray()) as PrivateKey
                    val sig = Signature.getInstance("SHA512withECDSA")
                    
                    sig.initSign(privateKey)
                    sig.update(data)
                    
                    result.success(sig.sign())
                } else {
                    result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("CRYPTO_ERROR", "Fallo al procesar el certificado: ${e.message}", null)
            }
        }
    }
}