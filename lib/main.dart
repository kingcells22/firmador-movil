import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const FirmadorMovilApp());
}

class FirmadorECDSA implements IPdfExternalSigner {
  final String rutaP12;
  final String clave;
  static const platform = MethodChannel('com.csice.firmador/crypto');

  FirmadorECDSA(this.rutaP12, this.clave);

  @override
  DigestAlgorithm get hashAlgorithm => DigestAlgorithm.sha512;

  @override
  int get estimatedSignatureSize => 8192;

  @override
  Future<SignerResult?> sign(List<int> message) async {
    try {
      final Uint8List signature = await platform.invokeMethod('signECDSA', {
        'path': rutaP12,
        'password': clave,
        'data': Uint8List.fromList(message),
      });
      return SignerResult(signature.toList());
    } catch (e) {
      throw Exception('Error firmando nativamente en Android: $e');
    }
  }

  @override
  SignerResult? signSync(List<int> message) {
    throw UnsupportedError(
      'La firma síncrona no está soportada en este entorno.',
    );
  }
}

class FirmadorMovilApp extends StatelessWidget {
  const FirmadorMovilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firmador SOFII',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final TextEditingController _pdfController = TextEditingController();
  final TextEditingController _certController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _puedeFirmar = false;
  bool _estaCargando = false;

  double? sigX;
  double? sigY;
  int? sigPage;
  double sigWidth = 250.0;
  double sigHeight = 70.0;

  List<List<int>>? _certificateChain;
  String _certFullSubject = '';

  String? _keyType;

  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool _tieneHuellaGuardada = false;

  @override
  void initState() {
    super.initState();
    _cargarCertificadoGuardado();
  }

  Future<void> _cargarCertificadoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final rutaGuardada = prefs.getString('ruta_certificado_p12');
    if (rutaGuardada != null && rutaGuardada.isNotEmpty) {
      setState(() {
        _certController.text = rutaGuardada;
      });
      await _verificarHuellaGuardada(rutaGuardada);
    }
  }

  Future<void> _verificarHuellaGuardada(String rutaCert) async {
    String? pass = await secureStorage.read(key: rutaCert);
    setState(() {
      _tieneHuellaGuardada = pass != null;
    });
  }

  Future<void> _seleccionarPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      String pathPDF = result.files.single.path!;

      if (!mounted) return;

      final coordenadas = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisorPDFScreen(rutaPdf: pathPDF),
        ),
      );
      if (coordenadas != null) {
        setState(() {
          _pdfController.text = pathPDF;
          sigX = coordenadas['x'];
          sigY = coordenadas['y'];
          sigPage = coordenadas['page'];
        });
      }
    }
  }

  Future<void> _seleccionarCertificado() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pfx'],
    );
    if (result != null) {
      String pathCertificado = result.files.single.path ?? '';
      setState(() {
        _certController.text = pathCertificado;
        _passController.clear();
        _puedeFirmar = false;
        _keyType = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ruta_certificado_p12', pathCertificado);
      await _verificarHuellaGuardada(pathCertificado);
    }
  }

  String _extraerAtributo(String subjectLine, String atributo) {
    final regExp = RegExp('$atributo=([^,]+)');
    final match = regExp.firstMatch(subjectLine);
    return match != null ? match.group(1)!.trim() : '';
  }

  String _extraerCargo(String subjectLine) {
    var regExp = RegExp(
      r'(?:2\.5\.4\.12|OID\.2\.5\.4\.12|T|TITLE)\s*=\s*([^,]+)',
    );
    var match = regExp.firstMatch(subjectLine);

    if (match != null) {
      String valor = match.group(1)!.trim();
      if (valor.startsWith('#')) {
        String hexStr = valor.substring(1);
        try {
          List<int> bytes = [];
          for (int i = 0; i < hexStr.length; i += 2) {
            bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
          }
          String rawString = utf8.decode(bytes, allowMalformed: true);
          return rawString.replaceAll(RegExp(r'[\x00-\x1F]'), '');
        } catch (e) {
          return '';
        }
      }
      return valor;
    }
    return '';
  }

  Future<void> _autenticarConHuella() async {
    try {
      bool autenticado = await auth.authenticate(
        localizedReason: 'Verifique su identidad para firmar el documento',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (autenticado) {
        String? passGuardada = await secureStorage.read(
          key: _certController.text,
        );
        if (passGuardada != null) {
          setState(() {
            _passController.text = passGuardada;
          });
          await _validarCertificado(omitirAlertaGuardado: true);
        }
      }
    } catch (e) {
      _mostrarAlerta(
        'Error Biométrico',
        'No se pudo leer la huella: $e',
        Colors.red,
      );
    }
  }

  void _preguntarGuardarHuella() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔐 ¿Activar Firma Rápida?'),
        content: const Text(
          '¿Desea usar su huella dactilar para no tener que escribir la contraseña la próxima vez que firme con este certificado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'No, gracias',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await secureStorage.write(
                key: _certController.text,
                value: _passController.text,
              );
              setState(() {
                _tieneHuellaGuardada = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '¡Huella configurada con éxito!',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Sí, activar huella'),
          ),
        ],
      ),
    );
  }

  Future<void> _validarCertificado({bool omitirAlertaGuardado = false}) async {
    if (_certController.text.isEmpty || _passController.text.isEmpty) {
      _mostrarAlerta(
        'Campos Vacíos',
        'Falta el certificado o la contraseña.',
        Colors.red,
      );
      return;
    }

    setState(() => _estaCargando = true);

    try {
      Map<dynamic, dynamic> certInfo;
      try {
        certInfo = await FirmadorECDSA.platform.invokeMethod('getCertInfo', {
          'path': _certController.text,
          'password': _passController.text,
        });
      } catch (e) {
        _mostrarAlerta(
          'Acceso Denegado',
          'Contraseña incorrecta o archivo .p12 dañado.',
          Colors.red,
        );
        setState(() => _puedeFirmar = false);
        return;
      }

      _certFullSubject = certInfo['subject'] ?? '';
      String nombrePropietario = _extraerAtributo(_certFullSubject, 'CN');
      if (nombrePropietario.isEmpty) nombrePropietario = 'Usuario FII';

      String serialReal = certInfo['serial'] ?? '';
      _keyType = certInfo['keyType'] ?? '';

      List<dynamic> rawChain = certInfo['chain'];
      _certificateChain = rawChain
          .map((e) => (e as Uint8List).toList())
          .toList();

      final String ocspUrl =
          "https://verificador.fii.gob.ve/ocspVerifySerial.php";
      HttpClient client = HttpClient();
      client.badCertificateCallback =
          ((X509Certificate c, String host, int port) => true);
      HttpClientRequest request = await client.postUrl(Uri.parse(ocspUrl));

      request.headers.set(
        'SOFE_AUTH',
        '9uI9N5Z7tqCx',
        preserveHeaderCase: true,
      );
      request.headers.set(
        'Content-Type',
        'application/x-www-form-urlencoded',
        preserveHeaderCase: true,
      );
      request.headers.set(
        'User-Agent',
        'python-requests/2.28.1',
        preserveHeaderCase: true,
      );

      request.write("serial=$serialReal");

      HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        var jsonRespuesta = jsonDecode(responseBody);
        String estado =
            jsonRespuesta['status']?.toString().toLowerCase() ?? 'desconocido';

        if (estado == 'revoked') {
          _mostrarAlerta(
            'Certificado Revocado',
            'Propietario: $nombrePropietario\n\nEste certificado está REVOCADO.',
            Colors.red,
          );
          setState(() => _puedeFirmar = false);
        } else if (estado == 'valid' || estado == 'good') {
          _mostrarAlerta(
            'Certificado Válido',
            'Propietario: $nombrePropietario\nSerial: $serialReal\nTipo: $_keyType\n\nEl certificado es válido y auténtico. ¡Puede firmar!',
            Colors.green,
          );
          setState(() => _puedeFirmar = true);

          if (!_tieneHuellaGuardada && !omitirAlertaGuardado) {
            Future.delayed(
              const Duration(seconds: 1),
              () => _preguntarGuardarHuella(),
            );
          }
        } else {
          _mostrarAlerta(
            'Validación Incompleta',
            'El servidor respondió: $estado\n\nSin embargo, la clave es correcta. Puede firmar localmente.',
            Colors.orange,
          );
          setState(() => _puedeFirmar = true);
        }
      } else {
        _mostrarAlerta(
          'Error',
          'El OCSP devolvió código ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (e) {
      _mostrarAlerta(
        'Error',
        'No se pudo contactar al servidor: $e',
        Colors.red,
      );
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  Future<void> _firmarDocumento() async {
    if (sigX == null ||
        _pdfController.text.isEmpty ||
        _certificateChain == null)
      return;

    setState(() => _estaCargando = true);

    try {
      final List<int> pdfBytes = await File(_pdfController.text).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final PdfPage page = document.pages[sigPage! - 1];

      final PdfSignature signature = PdfSignature(
        contactInfo: 'Sistema SOFII - FII',
        locationInfo: 'Caracas, Venezuela',
        reason: 'Firma Digital Autorizada',
      );

      signature.addExternalSigner(
        FirmadorECDSA(_certController.text, _passController.text),
        _certificateChain!,
      );

      double startX = sigX! - (sigWidth / 2);
      double startY = sigY! - (sigHeight / 2);

      if (startX < 0) startX = 0;
      if (startY < 0) startY = 0;

      final PdfSignatureField signatureField = PdfSignatureField(
        page,
        'Firma_SOFII_${DateTime.now().millisecondsSinceEpoch}',
        bounds: Rect.fromLTWH(startX, startY, sigWidth, sigHeight),
      );

      String nombre = _extraerAtributo(_certFullSubject, 'CN');
      String organizacion = _extraerAtributo(_certFullSubject, 'O');
      String cargo = _extraerCargo(_certFullSubject);

      DateTime now = DateTime.now();
      String fechaHora =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      String textoVisual = nombre;
      if (organizacion.isNotEmpty) textoVisual += '\n$organizacion';
      if (cargo.isNotEmpty) textoVisual += '\n$cargo';
      textoVisual += '\n$fechaHora';

      signatureField.appearance.normal.graphics?.drawString(
        textoVisual,
        PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        bounds: Rect.fromLTWH(0, 0, sigWidth, sigHeight),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      signatureField.signature = signature;
      document.form.fields.add(signatureField);

      final List<int> bytesFirmados = await document.save();
      document.dispose();

      // --- ¡NUEVA LÓGICA DE PERMISOS AUTOMÁTICOS PARA ANDROID 11 a 15! ---
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted) {
          var status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            _mostrarAlerta(
              'Permiso Denegado',
              'Para guardar el PDF firmado, Android requiere que le dé permiso a la aplicación. Intente firmar nuevamente y acepte el permiso.',
              Colors.red,
            );
            setState(() => _estaCargando = false);
            return;
          }
        }
      }
      // -------------------------------------------------------------------

      Directory dirFirmados = Directory(
        '/storage/emulated/0/Download/Firmados',
      );
      if (!await dirFirmados.exists()) {
        await dirFirmados.create(recursive: true);
      }

      String nombreOriginal = _pdfController.text.split('/').last;
      String nombreSinExt = nombreOriginal.replaceAll('.pdf', '');
      String rutaGuardado = '${dirFirmados.path}/${nombreSinExt}_firmado.pdf';

      File archivoFirmado = File(rutaGuardado);
      await archivoFirmado.writeAsBytes(bytesFirmados);

      setState(() {
        _puedeFirmar = false;
        if (!_tieneHuellaGuardada) {
          _passController.clear();
        }
      });

      _mostrarAlerta(
        '¡Firma Exitosa!',
        'Documento guardado en:\n\n$rutaGuardado',
        Colors.green,
      );
    } catch (e) {
      _mostrarAlerta(
        'Error al Firmar',
        'Problema criptográfico: $e',
        Colors.red,
      );
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  void _mostrarAlerta(String titulo, String mensaje, Color colorTitulo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          titulo,
          style: TextStyle(color: colorTitulo, fontWeight: FontWeight.bold),
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/img/logo_csice.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  Image.asset(
                    'assets/img/SOFII.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  Image.asset(
                    'assets/img/fii.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleccionar PDF:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pdfController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Ruta del documento...',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                          ),
                          onPressed: _seleccionarPDF,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Seleccionar certificado (.p12):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _certController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Ruta del certificado...',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.vpn_key, color: Colors.orange),
                          onPressed: _seleccionarCertificado,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Contraseña:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    _tieneHuellaGuardada
                        ? InkWell(
                            onTap: _autenticarConHuella,
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 30,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Tocar para validar con huella',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : TextField(
                            controller: _passController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Ingrese la clave de su certificado',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                    const SizedBox(height: 40),

                    _estaCargando
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (!_tieneHuellaGuardada)
                                    ElevatedButton.icon(
                                      onPressed: _validarCertificado,
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Validar'),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: _puedeFirmar
                                        ? _firmarDocumento
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.edit_document),
                                    label: const Text('Firmar PDF'),
                                  ),
                                ],
                              ),
                              if (_keyType == "RSA" && _puedeFirmar)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade800,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Módulo de pagos SIGECOF en desarrollo...',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.account_balance_wallet,
                                      ),
                                      label: const Text(
                                        'Validar Pagos SIGECOF',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisorPDFScreen extends StatefulWidget {
  final String rutaPdf;
  const VisorPDFScreen({super.key, required this.rutaPdf});
  @override
  State<VisorPDFScreen> createState() => _VisorPDFScreenState();
}

class _VisorPDFScreenState extends State<VisorPDFScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  void _confirmarPosicion(BuildContext context, double x, double y, int page) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estampar Firma'),
        content: Text(
          '¿Deseas ubicar tu firma visual aquí en la página $page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {'x': x, 'y': y, 'page': page});
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Toque donde desea firmar',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(
        File(widget.rutaPdf),
        controller: _pdfViewerController,
        onTap: (PdfGestureDetails details) => _confirmarPosicion(
          context,
          details.pagePosition.dx,
          details.pagePosition.dy,
          details.pageNumber,
        ),
      ),
    );
  }
}
