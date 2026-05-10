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
import 'package:path_provider/path_provider.dart';

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
      throw Exception('Error en firma nativa: $e');
    }
  }

  @override
  SignerResult? signSync(List<int> message) {
    throw UnsupportedError('La firma síncrona no está soportada.');
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
  final TextEditingController _imgController = TextEditingController();

  // --- NUEVAS VARIABLES PARA EL LOTE ---
  List<Map<String, dynamic>> _loteArchivos = [];
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

  Future<void> _seleccionarImagenFirma() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null) {
      setState(() {
        _imgController.text = result.files.single.path ?? '';
      });
    }
  }

  Future<void> _cargarCertificadoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final rutaGuardada = prefs.getString('ruta_certificado_p12');
    if (rutaGuardada != null && rutaGuardada.isNotEmpty) {
      setState(() => _certController.text = rutaGuardada);
      await _verificarHuellaGuardada(rutaGuardada);
    }
  }

  Future<void> _verificarHuellaGuardada(String rutaCert) async {
    String? pass = await secureStorage.read(key: rutaCert);
    setState(() => _tieneHuellaGuardada = pass != null);
  }

  // --- LÓGICA DE SELECCIÓN SECUENCIAL ---
  Future<void> _seleccionarPDFs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      List<String> paths = result.paths.whereType<String>().toList();
      _loteArchivos.clear();

      for (int i = 0; i < paths.length; i++) {
        String rutaActual = paths[i];
        String nombreDoc = rutaActual.split('/').last;

        if (!mounted) return;

        final coordenadas = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisorPDFScreen(
              rutaPdf: rutaActual,
              titulo: "Configurar Doc ${i + 1}/${paths.length}: $nombreDoc",
            ),
          ),
        );

        if (coordenadas != null) {
          _loteArchivos.add({
            'path': rutaActual,
            'x': coordenadas['x'],
            'y': coordenadas['y'],
            'page': coordenadas['page'],
          });
        } else {
          // Si el usuario cancela un solo visor, se aborta la carga del lote por seguridad
          _loteArchivos.clear();
          _pdfController.text = "Selección cancelada";
          return;
        }
      }

      setState(() {
        _pdfController.text = "${_loteArchivos.length} archivos configurados";
      });
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
          return utf8
              .decode(bytes, allowMalformed: true)
              .replaceAll(RegExp(r'[\x00-\x1F]'), '');
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
        localizedReason: 'Verifique su identidad para firmar',
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
          setState(() => _passController.text = passGuardada);
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
          '¿Desea usar su huella dactilar para este certificado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, gracias'),
          ),
          ElevatedButton(
            onPressed: () async {
              await secureStorage.write(
                key: _certController.text,
                value: _passController.text,
              );
              setState(() => _tieneHuellaGuardada = true);
              Navigator.pop(context);
            },
            child: const Text('Sí, activar'),
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
      Map<dynamic, dynamic> certInfo = await FirmadorECDSA.platform
          .invokeMethod('getCertInfo', {
            'path': _certController.text,
            'password': _passController.text,
          });

      _certFullSubject = certInfo['subject'] ?? '';
      _keyType = certInfo['keyType'] ?? '';

      // --- AGREGA ESTA LÍNEA AQUÍ PARA QUITAR EL ERROR ---
      String serialReal = certInfo['serial'] ?? 'No disponible';

      List<dynamic> rawChain = certInfo['chain'];
      _certificateChain = rawChain
          .map((e) => (e as Uint8List).toList())
          .toList();

      setState(() => _puedeFirmar = true);

      _mostrarAlerta(
        'Certificado Válido',
        'Propietario: ${_extraerAtributo(_certFullSubject, 'CN')}\nSerial: $serialReal\nTipo: $_keyType\n\nListo para procesar el lote.',
        Colors.green,
      );
      if (!_tieneHuellaGuardada && !omitirAlertaGuardado) {
        Future.delayed(
          const Duration(seconds: 1),
          () => _preguntarGuardarHuella(),
        );
      }
    } catch (e) {
      _mostrarAlerta('Error', 'Acceso denegado o archivo dañado.', Colors.red);
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // --- PROCESAMIENTO EN LOTE CON POSICIONES INDIVIDUALES ---
  Future<void> _firmarLoteDocumentos() async {
    if (_loteArchivos.isEmpty || _certificateChain == null) return;

    setState(() => _estaCargando = true);
    int contadorExitos = 0;

    try {
      if (Platform.isAndroid &&
          !await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      String rutaBase = Platform.isAndroid
          ? '/storage/emulated/0/Download/Firmados'
          : '${(await getApplicationDocumentsDirectory()).path}/Firmados';
      Directory dirFirmados = Directory(rutaBase);
      if (!await dirFirmados.exists())
        await dirFirmados.create(recursive: true);

      for (var doc in _loteArchivos) {
        final List<int> pdfBytes = await File(doc['path']).readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
        final PdfPage page = document.pages[doc['page'] - 1];

        final PdfSignature signature = PdfSignature(
          contactInfo: 'Sistema SOFII - FII',
          locationInfo: 'Caracas, Venezuela',
          reason: 'Firma Digital Autorizada',
        );

        signature.addExternalSigner(
          FirmadorECDSA(_certController.text, _passController.text),
          _certificateChain!,
        );

        final PdfSignatureField signatureField = PdfSignatureField(
          page,
          'Firma_SOFII_${DateTime.now().millisecondsSinceEpoch}',
          bounds: Rect.fromLTWH(
            doc['x'] - (sigWidth / 2),
            doc['y'] - (sigHeight / 2),
            sigWidth,
            sigHeight,
          ),
        );

        if (_imgController.text.isNotEmpty) {
          final Uint8List imgBytes = await File(
            _imgController.text,
          ).readAsBytes();
          signatureField.appearance.normal.graphics?.drawImage(
            PdfBitmap(imgBytes),
            Rect.fromLTWH(0, 0, sigWidth, sigHeight),
          );
        } else {
          String nombre = _extraerAtributo(_certFullSubject, 'CN');
          String cargo = _extraerCargo(_certFullSubject);
          String fecha = DateTime.now().toString().substring(0, 19);
          signatureField.appearance.normal.graphics?.drawString(
            "$nombre\n$cargo\n$fecha",
            PdfStandardFont(PdfFontFamily.helvetica, 11),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(0, 0, sigWidth, sigHeight),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }

        signatureField.signature = signature;
        document.form.fields.add(signatureField);
        final List<int> bytesFirmados = await document.save();
        document.dispose();

        String nombreArchivo = doc['path']
            .split('/')
            .last
            .replaceAll('.pdf', '');
        await File(
          '${dirFirmados.path}/${nombreArchivo}_firmado.pdf',
        ).writeAsBytes(bytesFirmados);
        contadorExitos++;
      }

      _mostrarAlerta(
        'Firma Masiva Exitosa',
        'Se procesaron $contadorExitos documentos correctamente.',
        Colors.green,
      );
      setState(() => _loteArchivos.clear());
      _pdfController.clear();
    } catch (e) {
      _mostrarAlerta('Error en Lote', 'Ocurrió un error: $e', Colors.red);
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/img/logo_csice.png', height: 40),
                  Image.asset('assets/img/SOFII.png', height: 40),
                  Image.asset('assets/img/fii.png', height: 40),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleccionar PDFs (Lote):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pdfController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Configurar documentos...',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                          ),
                          onPressed: _seleccionarPDFs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Certificado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _certController,
                            readOnly: true,
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
                      'Firma con Imagen (Opcional):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _imgController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Firma con Imagen',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.purple),
                          onPressed: _seleccionarImagenFirma,
                        ),
                        if (_imgController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () =>
                                setState(() => _imgController.clear()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Seguridad:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _tieneHuellaGuardada
                        ? ListTile(
                            leading: const Icon(
                              Icons.fingerprint,
                              color: Colors.blue,
                            ),
                            title: const Text('Validar con huella'),
                            onTap: _autenticarConHuella,
                            tileColor: Colors.blue.withOpacity(0.05),
                          )
                        : TextField(
                            controller: _passController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Contraseña',
                            ),
                          ),
                    const SizedBox(height: 40),
                    _estaCargando
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (!_tieneHuellaGuardada)
                                ElevatedButton(
                                  onPressed: _validarCertificado,
                                  child: const Text('Validar'),
                                ),
                              ElevatedButton.icon(
                                onPressed:
                                    _puedeFirmar && _loteArchivos.isNotEmpty
                                    ? _firmarLoteDocumentos
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.edit_document),
                                label: Text(
                                  _loteArchivos.length > 1
                                      ? 'Firmar Lote'
                                      : 'Firmar PDF',
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Desarrollado por: Kenmerry Navarro para FIIIDT',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
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
  final String titulo;
  const VisorPDFScreen({
    super.key,
    required this.rutaPdf,
    required this.titulo,
  });
  @override
  State<VisorPDFScreen> createState() => _VisorPDFScreenState();
}

class _VisorPDFScreenState extends State<VisorPDFScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(
        File(widget.rutaPdf),
        controller: _pdfViewerController,
        onTap: (details) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirmar Posición'),
              content: const Text('¿Desea ubicar su firma aquí?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, {
                      'x': details.pagePosition.dx,
                      'y': details.pagePosition.dy,
                      'page': details.pageNumber,
                    });
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
