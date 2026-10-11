# Barrioteca Acalenca - App iOS (iPhone/iPad)

App nativa para iOS de la Barrioteca Acalenca, generada con un **WKWebView** que empaqueta la app web.

> **Estado actual:** no hay cuenta de Apple Developer, asi que la app **no esta en la App Store**.
> Los usuarios de iOS usan la **PWA instalable** (`https://www.corrientelebeche.es/barrioteca/`). Este repo
> queda **compilable y operativo desde CI** (IPA sin firmar) para cuando exista cuenta y se pueda publicar.

## Requisitos

- **Mac** con macOS 13 (Ventura) o superior
- **Xcode 15** o superior (descargar desde la App Store)
- **Apple Developer Account** solo para publicar en la App Store ($99/año). Para compilar el IPA sin firmar desde CI no hace falta cuenta.

## Como generar la app iOS

La app iOS se genera con un proyecto Xcode que carga la app web en un `WKWebView`:

1. Crea un nuevo proyecto en Xcode: **iOS -> App**
2. Sustituye el `ContentView.swift` por un `WKWebView` que cargue la URL
3. Añade permisos de cámara en `Info.plist` para el escaner de codigos
4. Configura el `apple-app-site-association` en tu NAS

## Datos tecnicos

| Dato | Valor |
|------|-------|
| Bundle ID | `com.barrioteca.acalenca.ios` |
| URL | `https://www.corrientelebeche.es/barrioteca` |
| Tecnologia | WKWebView (WebKit) |
| Version minima iOS | 15.0 |
| Permisos | Camara (NSCameraUsageDescription) |
| Orientacion | Portrait |

## Configuracion del NAS para iOS

Para que la app iOS funcione correctamente, necesitas anadir el archivo `apple-app-site-association` en tu NAS:

1. Sube el archivo `apple-app-site-association` (incluido en este repo) a:
   - `/barrioteca/.well-known/apple-app-site-association`
   - O bien a la raiz del dominio: `https://www.corrientelebeche.es/.well-known/apple-app-site-association`

2. El archivo debe servirse sin extension `.json` y con content-type `application/json`

Puedes subir el archivo por **SMB** (`\\192.168.50.94\`) o por **SFTP** (`192.168.50.93`, puerto 22).

## Permisos de camara (Info.plist)

Anade esto al `Info.plist` del proyecto Xcode:

```xml
<key>NSCameraUsageDescription</key>
<string>La Barrioteca necesita acceder a la camara para escanear los codigos de barras de los libros y las tarjetas de socias.</string>
```

## Sideloading (sin cuenta de desarrollador)

Mientras no haya cuenta de Apple Developer, el IPA sin firmar que genera el CI se puede instalar en un iPhone
propio usando [Sideloadly](https://sideloadly.io/) (Windows/macOS) con un **Apple ID gratuito**:

1. Descarga el artefacto `Barrioteca-iOS-unsigned` del workflow de GitHub Actions.
2. Abre Sideloadly, arrastra el `.ipa`, introduce tu Apple ID y pulsa Start.
3. En el iPhone: Ajustes -> General -> VPN y gestion de dispositivos -> confia en el desarrollador.

La instalacion caduca a los **7 dias** (hay que repetir el proceso). Para una instalacion permanente hace falta publicar en la App Store.

## Publicar en la App Store

> **Pendiente**: requiere una cuenta de **Apple Developer Program** de pago.

1. **Apple Developer Program**: $99 USD/ano
2. En Xcode: Product -> Archive -> Distribute App
3. Subir a App Store Connect
4. Completar ficha: descripcion, capturas, politica de privacidad
5. Esperar revision (1-2 dias)

### Politica de privacidad

La app no recopila datos personales. Todo el procesamiento ocurre en el NAS de la barrioteca. La URL de privacidad puede ser:

```
https://www.corrientelebeche.es/barrioteca/privacidad.html
```

## Estructura del repositorio

```
barrioteca-ios/
├── README.md
├── apple-app-site-association    # Configuracion Universal Links
└── .gitignore
```

## Repositorio

- **Local**: `g:\GITHUB\barrioteca-ios\`
- **GitHub**: https://github.com/jesuscastilla/barrioteca-ios

## Repositorios relacionados

| Repositorio | Descripcion |
|------------|-------------|
| [barrioteca-web](https://github.com/jesuscastilla/barrioteca-web) | App web (frontend React) |
| [barrioteca-slims](https://github.com/jesuscastilla/barrioteca-slims) | SLiMS (backend PHP) |
| [barrioteca-android](https://github.com/jesuscastilla/barrioteca-android) | App Android nativa (Kotlin/Compose) |

## Creditos

Desarrollado por [**Peloxi**](https://jesuscastilla.github.io/portfolio-pelotxo/) ([@Pelochochi](https://instagram.com/Pelochochi)) para la **Barrioteca Acalenca**, espacio perteneciente a **Lebeche**, asociacion cultural y vecinal de Salobrena (Granada).

## Licencia

[GNU General Public License v3.0](LICENSE)