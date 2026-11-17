# Security Policy

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private vulnerability reporting (Security tab, *Report a
vulnerability*), or send the report by email to **nbdigitalsas@gmail.com** with a subject that starts exactly like
this:

```text
[NB Sound Mobile][Seguridad] <one-line summary>
```

The mailbox is shared by every NB Digital project and is filtered by that prefix.

Please include a description of the problem and the affected component, steps to reproduce, the estimated impact
and the app version (General, About).

## What to expect

| Step | Commitment |
|---|---|
| Acknowledgement | Within 7 days |
| Assessment and plan | Within 30 days |
| Public disclosure | Coordinated; the reporter may disclose 90 days after acknowledgement |
| Publication | Fixed release and security advisory, with credit if desired |

The Spanish reference is [`docs/legal/security-policy.md`](docs/legal/security-policy.md).

## Scope

**In scope:** the Android and iOS application, its native code, the single network exit (`lib/core/network/`),
pairing and TLS pinning with the PC, the in-app updater, and the build and release tooling.

**Out of scope:** NB Sound on the PC (report it to its own repository), third-party operating-system software and
modified builds. The threat model is in [`docs/audit/threat-model.md`](docs/audit/threat-model.md).

## Cryptographic scope

| Use | Mechanism |
|---|---|
| Release integrity | `SHA256SUMS` over every artefact, signed with **Ed25519** (`SHA256SUMS.sig`) |
| Android packages | APK signature with the NB Sound Mobile key (certificate fingerprint in [supply chain](docs/audit/supply-chain.md)) |
| Transport to the PC | TLS with the PC certificate pinned by its SHA-256 fingerprint |
| Stored credentials | Android Keystore / iOS Keychain; never in the database or settings |

## Supported versions

Security fixes are released for the latest published version.
