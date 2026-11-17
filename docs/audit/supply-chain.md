# Cadena de suministro

> **Estado:** Implementado.

## Dependencias

* Versiones fijadas en `pubspec.lock`, que se versiona.
* Licencias comprobadas en cada verificación por `tool/guardianes/licencias.dart`; avisos generados en
  `THIRD-PARTY-NOTICES.md` ([política](../architecture/dependency-policy.md)).
* Dependabot vigila `pub`, Gradle y GitHub Actions **solo con alertas**: no abre pull requests
  (`open-pull-requests-limit: 0`). Las actualizaciones se hacen a mano y se verifican con la suite completa.

## Alertas

Una alerta nueva se resuelve actualizando la dependencia. Una alerta que no afecte a la app y no tenga arreglo se
descarta en GitHub con su motivo escrito y se anota aquí con la fecha.

| Fecha | Alerta | Motivo |
|---|---|---|
| — | Ninguna descartada | — |

## Firma de las publicaciones

* Los APK se firman con la clave de NB Sound Mobile (RSA 2048). La huella SHA-256 del certificado es
  `00:59:0F:10:20:E1:E9:1C:33:74:E3:D2:22:11:D2:48:0D:73:32:F5:F8:29:01:AC:0E:5F:BD:19:49:3B:F7:2D`.
* `SHA256SUMS` lista la huella de cada archivo de la publicación y `SHA256SUMS.sig` es su firma Ed25519 con la
  clave de publicación de NB Digital, cuya parte pública está en
  [`clave-de-publicacion.pem`](../architecture/api/clave-de-publicacion.pem).
* El `.ipa` de iOS sale de GitHub Actions sin firma de Apple y entra en la misma lista firmada.

Comprobación ([publicación](../developer/releases.md)):

```bash
openssl pkeyutl -verify -pubin -inkey clave-de-publicacion.pem -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
sha256sum --check --strict SHA256SUMS
```

## Lo que no entra en el repositorio

Claves privadas, almacenes de firma, `key.properties`, binarios compilados y configuración de herramientas de
agentes (`tool/guardianes/secretos.dart`).
