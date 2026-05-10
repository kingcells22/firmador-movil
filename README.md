# 📱 Sofii Móvil v2.0 - Ecosistema de Firma Digital y Pagos

**Desarrollado por: Kenmerry Navarro ** _Ciberseguridad y Arquitectura de Software_

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white" alt="Kotlin">
  <img src="https://img.shields.io/badge/Cryptography-🔐-yellow?style=for-the-badge" alt="Cryptography">
  <img src="https://img.shields.io/badge/Security-Zero--Trust-black?style=for-the-badge" alt="Zero-Trust">
</p>

## 📄 Descripción General

**Sofii Móvil** es una solución de vanguardia diseñada para la gestión documental segura. Esta aplicación permite a la **Alta Gerencia** y personal autorizado estampar firmas electrónicas con **plena validez legal** directamente desde su smartphone, optimizando los flujos de trabajo institucionales.

### 📸 Interfaz de la Aplicación

<p align="center">
  <img src="https://files.oaiusercontent.com/file-6lY3P9WjDovr0N9f2W48Dq9W" alt="Interfaz de Sofii Móvil v2.0" width="350px">
</p>

---

## ✨ Características Principales (v2.0)

- **⚡ Firma Multialgoritmo:** Soporte nativo para certificados **ECDSA (curva elíptica)** y **RSA (2048/4096 bits)**, garantizando compatibilidad con cualquier Autoridad de Certificación.
- **📦 Firma en Lote (Masiva):** Capacidad para seleccionar múltiples PDFs y firmarlos secuencialmente en un solo proceso.
- **🖼️ Estampa Visual Personalizada:** Permite cargar una imagen (sello o firma manuscrita) y ubicarla táctilmente en el documento.
- **☝️ Biometría Inteligente:** Tras la primera validación, el app cifra las credenciales en el hardware seguro (`Keystore`) para permitir firmas futuras solo con la huella dactilar.
- **💳 Módulo SIGECOF (Beta):** Integración preparada para el sistema de pagos SIGECOF. _Nota: Pendiente de configuración de rutas finales por parte del ente rector._

---

## 🚀 Guía de Uso para el Usuario

### 1. Instalación y Permisos

1. Descargue el archivo **`Sofii Movil.apk`**.
2. Si el sistema bloquea la instalación, vaya a **Ajustes > Seguridad** y active **"Instalar aplicaciones de orígenes desconocidos"**.
3. Si ya tiene una versión anterior, instale encima para **actualizar** sin perder sus datos.

### 2. Proceso de Firma

- **Selección:** Use el ícono de **PDF** para cargar uno o varios archivos.
- **Certificado:** Cargue su archivo `.p12` o `.pfx` y valide su contraseña.
- **Firma con Imagen:** (Opcional) Cargue su sello y toque el visor para posicionarlo.
- **Ejecución:** Presione **"Firmar PDF"** (o "Firmar Lote" si son varios).

### 3. Ubicación de Archivos

Todos los documentos firmados se guardan automáticamente en:  
`📁 Almacenamiento Interno > Download > Firmados`.

---

## 🛠️ Arquitectura Técnica

### Seguridad "Zero-Trust" en el Dispositivo

1. **Frontend (Flutter):** Maneja la UI y el visor táctil.
2. **Puente (Method Channel):** Envía datos de forma binaria y asíncrona al núcleo nativo.
3. **Core Nativo (Kotlin):** Realiza el cálculo matemático de la firma dentro del **TEE (Trusted Execution Environment)** de Android. La clave privada nunca se expone fuera de la memoria volátil protegida.

### Especificaciones de Criptografía

- **Algoritmos:** ECDSA con SHA-512 / RSA con SHA-256.
- **Resguardo:** Encriptación de contraseñas mediante **AES-256-GCM** vinculada a la biometría del hardware.

---

<p align="center">
  <b>Kenmerry Jemahel Navarro Ayala</b><br>
  <i>Coordinador de Tecnología / Especialista en PKI y Seguridad</i><br>
  FIIIDT
</p>
