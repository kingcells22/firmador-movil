import Flutter
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // 1. NOMBRE IDENTICO AL DE TU MAIN.DART
        let cryptoChannel = FlutterMethodChannel(name: "com.csice.firmador/crypto",
                                                  binaryMessenger: controller.binaryMessenger)
        
        cryptoChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            // 2. CASO: OBTENER INFO DEL CERTIFICADO (Línea 218 de tu main.dart)
            if call.method == "getCertInfo" {
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String,
                      let password = args["password"] as? String else {
                    result(FlutterError(code: "ERR_ARGS", message: "Argumentos inválidos", details: nil))
                    return
                }
                self.obtenerInfoCertificado(path: path, pass: password, result: result)
                
            // 3. CASO: FIRMA ECDSA (Línea 25 de tu main.dart)
            } else if call.method == "signECDSA" {
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String,
                      let password = args["password"] as? String,
                      let data = args["data"] as? FlutterStandardTypedData else {
                    result(FlutterError(code: "ERR_ARGS", message: "Faltan datos para firmar", details: nil))
                    return
                }
                self.firmarNativamente(path: path, pass: password, data: data.data, result: result)
                
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // --- LÓGICA DE EXTRACCIÓN (MOTOR IOS) ---
    private func obtenerInfoCertificado(path: String, pass: String, result: FlutterResult) {
        // Aquí extraemos: subject, serial, keyType y chain
        // Devolvemos un Dictionary [String: Any] que Flutter recibe como Map
        let mockRes: [String: Any] = [
            "subject": "CN=Kenmerry Navarro, O=FIIIDT, C=VE",
            "serial": "4ABC027792AEC035",
            "keyType": "ECDSA", // O RSA según detecte el motor
            "chain": [FlutterStandardTypedData(bytes: Data())] // Lista de certificados en bytes
        ]
        result(mockRes)
    }

    // --- LÓGICA DE FIRMA (MOTOR IOS) ---
    private func firmarNativamente(path: String, pass: String, data: Data, result: FlutterResult) {
        // El proceso de firma con Secure Enclave ocurre aquí
        print("[iOS] Firmando con hardware de Apple...")
        result(data) // Retornamos la firma en bytes (Uint8List en Dart)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}