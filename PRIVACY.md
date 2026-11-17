# Privacy Statement

This statement describes what NB Sound Mobile does with your data. It is enforced by the code and by automated
checks that run on every change. The detailed Spanish reference is [docs/audit/privacy.md](docs/audit/privacy.md).

## 1. No account, no cloud, no telemetry

* No feature requires registration, an email address or a sign-in.
* Your music travels from your own PC to your phone over your local network. NB Digital operates no server that
  receives it.
* The app contains **no** analytics, usage tracking, crash reporting or advertising identifiers, and it writes
  **no** logs (`tool/guardianes/registro.dart`).

## 2. Network access

Every connection is built in one place, `lib/core/network/`; any client elsewhere fails the checks
(`tool/guardianes/red.dart`). There are exactly two destinations, both requested by you:

| Destination | What is sent | When |
|---|---|---|
| The PC you paired | Phone name and platform when pairing; listening history, favourites and sync selection; requests for catalogue, media and player commands | When you pair, sync, play or control the PC |
| GitHub (`api.github.com`, `github.com`) | An anonymous request for the latest release | Only when you tap "Check for updates" or "Install" (Android) |

The PC certificate is pinned by its fingerprint when you pair. Music stored only on your phone is never sent to the
PC.

## 3. What stays on the phone

The received catalogue, history, favourites, playlists, downloads, preferences, and your profile name and photo.
The pairing token and the PC fingerprint are kept in the system keychain. Uninstalling the app removes everything.

## 4. Permissions

Network (local network on iOS), camera (only while scanning the QR code), notifications and foreground service
(background playback), audio files (local music, Android) and package installation (updates you request, Android).
