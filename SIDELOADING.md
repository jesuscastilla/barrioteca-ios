# Instalacion en iPhone/iPad sin cuenta de desarrollador (Sideloading)

Guia para instalar el IPA sin firmar de la Barrioteca en un iPhone/iPad **sin** cuenta de Apple Developer, usando [Sideloadly](https://sideloadly.io/).

> Importante: con un Apple ID gratuito la app caduca a los **7 dias** y hay que repetir el proceso.
> Para una instalacion permanente hace falta publicar en la App Store.

## Requisitos

- Un **PC con Windows** (o Mac).
- [Sideloadly](https://sideloadly.io/) instalado (gratuito).
- Un **Apple ID** (puede ser gratuito; solo se usa para firmar la app).
- El **iPhone/iPad** conectado por cable USB de datos (en Windows, con iTunes o Apple Mobile Device Support instalado).
- El archivo `Barrioteca-iOS-unsigned.ipa` generado por GitHub Actions.

## Paso 1 - Descargar el IPA

1. Entra en el repositorio: https://github.com/jesuscastilla/barrioteca-ios
2. Pestaña **Actions** > ultimo workflow en verde > seccion **Artifacts**.
3. Descarga **Barrioteca-iOS-unsigned** (es un `.zip`; descomprimelo para obtener el `.ipa`).

## Paso 2 - Firmar e instalar con Sideloadly

1. Abre **Sideloadly**.
2. Arrastra el `Barrioteca-iOS-unsigned.ipa` a la ventana (campo "IPA").
3. Conecta el iPhone por USB y seleccionalo en el desplegable de dispositivos.
4. Introduce tu **Apple ID** y pulsa **Start**.
   - Si no tienes una contrasena de app, usa la contrasena normal de tu Apple ID.
5. Espera a que Sideloadly firme e instale. La app aparece en la pantalla de inicio como **Barrioteca Acalenca**.

## Paso 3 - Confiar en el desarrollador

La primera vez, iOS bloquea la app porque no viene de la App Store:

1. En el iPhone: **Ajustes > General > VPN y gestion de dispositivos**.
2. Toca el perfil de tu Apple ID.
3. Pulsa **Confiar** y confirma.

Despues de esto, abre la app con normalidad. La camara del escaner pedira permiso la primera vez.

## Limitaciones (Apple ID gratuito)

- La app **caduca a los 7 dias**: al cumplirse, se cierra al abrir. Hay que repetir el proceso (los datos de la web estan en el NAS, no se pierden).
- La app se instala **solo en tu dispositivo** (no se distribuye).
- **Universal Links no funcionan** con Apple ID gratuito (requieren cuenta de pago).
- Maximo **3 apps instaladas** por Apple ID gratuito.

## Resolver problemas

- **"Failed to verify app" o la app no abre tras 7 dias** -> vuelve a instalar con Sideloadly.
- **El dispositivo no aparece en Sideloadly** -> instala/actualiza iTunes (o Apple Mobile Device Support) y usa un cable USB de datos.
- **Error de login en Sideloadly** -> activa la verificacion en dos pasos en tu Apple ID y usa una contrasena de app (appleid.apple.com > Iniciar sesion y seguridad > Contrasenas de apps).
- **Superas el limite de 3 apps** -> borra apps caducadas o usa otro Apple ID.

## Alternativa

Para instalacion permanente y distribucion a otras personas, hace falta una cuenta de **Apple Developer Program** (99 USD/ano) y publicar en la App Store (ver `README.md`).
