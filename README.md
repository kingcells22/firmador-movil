# 📱 Firmador Móvil Criptográfico Zero-Trust

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white" alt="Kotlin">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Cryptography-🔐-yellow?style=for-the-badge" alt="Cryptography">
</p>

## 📄 Descripción General

**Firmador Móvil** es una solución de software de vanguardia diseñada para la gestión documental segura en dispositivos móviles. Esta aplicación permite a la **Alta Gerencia** y personal autorizado estampar firmas electrónicas con **plena validez legal** directamente desde su teléfono inteligente Android, eliminando la dependencia de equipos de escritorio.

### 📸 Interfaz de la Aplicación

<p align="center">
  <img src="./screeshots/Sofii movil app.jpeg" alt="Interfaz del Firmador Móvil" width="300px">
</p>

Desarrollada bajo una estricta arquitectura de seguridad **Zero-Trust** y cumplimiento de estándares criptográficos internacionales, garantiza la integridad, autenticidad y el no repudio de los documentos firmados.

## ✨ Características Principales

- **⚡ Firma On-Device:** El proceso criptográfico se ejecuta 100% localmente en el dispositivo. Las llaves privadas jamás viajan por la red.
- **📂 Soporte PDF:** Selección e interacción nativa con documentos en formato PDF.
- **🔑 Gestión de Certificados (.p12/.pfx):** Carga segura de certificados digitales estándar de la industria.
- **☝️ Autenticación Biométrica:** Integración con el sensor de huellas dactilares del dispositivo para autorizar la firma y proteger las credenciales.
- **🎯 Ubicación Visual Táctil:** El usuario decide exactamente dónde estampar la firma visual tocando la pantalla del visor PDF.
- **🏷️ Extracción de Metadatos X.509:** Generación automática de sellos visuales extrayendo el Nombre, Organización y Cargo directamente de la data encriptada del certificado.

## 🛠️ Arquitectura y Tecnologías

La aplicación utiliza un enfoque **Híbrido/Nativo** para combinar la agilidad de desarrollo con la seguridad de bajo nivel.

### El "Cómo" y el "Por Qué" Tecnológico

#### 🟦 Frontend: Flutter (Dart)

Usamos 💙 **Flutter** para construir una interfaz de usuario (UI) fluida, moderna y reactiva. Flutter maneja toda la lógica de presentación, el visor de PDF táctil, la selección de archivos y la navegación.

- **Ventaja:** Desarrollo rápido y una experiencia de usuario (UX) consistente y de alto rendimiento.

#### 🤖 Backend Nativo: Kotlin (Android)

Aquí está la "joya de la corona". Flutter, por sí solo, no tiene acceso directo a los motores criptográficos de bajo nivel del sistema operativo. Por lo tanto, creamos un motor criptográfico nativo en 💜 **Kotlin**.

- **Ventaja:** Seguridad de grado militar. Usamos las APIs nativas de Android (`java.security`) que están respaldadas, en muchos casos, por hardware dedicado (Trusted Execution Environment - TEE).

#### 🌉 El Puente: Method Channel

Flutter y Kotlin se comunican a través de un canal binario asíncrono seguro llamado **Method Channel**. Flutter envía el PDF y la clave encriptada a Kotlin; Kotlin "abre" la llave encriptada en la RAM protegida, firma el documento matemáticamente y devuelve el archivo firmado a Flutter.

## 🔐 Seguridad y Criptografía

- 🛡️ **Motor Criptográfico:** Implementación estricta de Curve Elíptica (ECDSA) con algoritmos de hashing SHA-512 y SHA-256 para máxima seguridad.
- 🔒 **Zero-Trust Arquitectura:** La contraseña del certificado (.p12) se captura en vivo, se usa en la memoria volátil y se destruye inmediatamente después del proceso matemático de firma. Nada se guarda desprotegido en el disco.
- 🔐 **Secure Storage:** Cuando el usuario activa la biometría, la contraseña del certificado se guarda encriptada en el llavero de hardware seguro de Android (`Keystore`) usando AES-256, protegido por la huella dactilar del usuario.

## 🚀 Guía de Uso Rápido

### Preparación

1.  **Instalación 📱:** Descargue e instale el archivo **`Sofii-Movil.apk`** en su dispositivo Android.
2.  **Permisos:** Permita la instalación de aplicaciones desconocidas si el sistema se lo solicita.

### Flujo de Firma

1.  **📄 Seleccionar PDF:** Abra la app, presione el ícono rojo de PDF y busque el documento a firmar.
2.  **🎯 Ubicar Firma:** Toque la pantalla sobre el visor PDF donde desea que aparezca el sello visual y presione "Aceptar".
3.  **🔑 Cargar Certificado:** Presione el ícono naranja de la llave y busque su archivo de firma electrónica (`.p12`).
4.  **🔓 Validar y Firmar:**
    - Si es la primera vez, ingrese la contraseña y presione **Validar**.
    - Si ya configuró la biometría, simplemente **toque el sensor de huella dactilar**.
5.  **✍️ Firmar PDF:** Una vez validado el certificado, el botón azul de "Firmar PDF" se habilitará. Presiónelo.
6.  **💾 Archivo Final:** ¡Listo! Su documento firmado se guardará automáticamente en la carpeta `Descargas > Firmados` de su teléfono.

## 🏆 Ventajas Competitivas

| Ventaja                | Descripción                                                                                  |
| :--------------------- | :------------------------------------------------------------------------------------------- |
| **Seguridad Militar**  | Protección de llaves privadas respaldada por hardware nativo de Android.                     |
| **Usabilidad Premium** | Firma con huella dactilar en 5 segundos. Experiencia de usuario bancaria.                    |
| **Validez Legal**      | Cumplimiento de algoritmos internacionales ECDSA/SHA-512 para el no repudio.                 |
| **Movilidad Total**    | Firme contratos, memorándums y autorizaciones desde cualquier lugar, sin depender de una PC. |

---

<p align="center">
Desarrollado y Mantenido por<br>
<b>Kenmerry Navarro (kingcells22)</b><br>
Ciberseguridad y Arquitectura de Software
</p>
