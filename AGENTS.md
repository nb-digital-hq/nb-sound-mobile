# AGENTS.md: operating contract for automated contributors

This file is the working contract of the repository for any coding agent (Claude, Gemini, Codex, Cursor, Copilot
or others) and for humans who want the same rules in one place. It applies **without anyone having to repeat it**.
Tool-specific configuration is never versioned in this repository and must never duplicate or contradict this
file.

The project documentation is written in Spanish; this file, the root community files and the issue templates are
in English. Code identifiers and comments are in Spanish.

---

## 1. The rule that governs all others

**`docs/` is the single source of truth.** If the code and `docs/` disagree, there is a defect: either the code is
fixed or the document is changed through the decision process. A contradiction is never left alive.

A change with architectural or user-facing impact **is not finished** until the affected document reflects it,
with its status label up to date, in the same pull request (Constitution, rule 7).

## 2. Before writing code, in this order

| Step | Document | What to look for |
|---|---|---|
| 1 | [Constitution](docs/architecture/constitution.md) | The absolute rules |
| 2 | [ADR index](docs/adr/README.md) | Why things are the way they are |
| 3 | [Architecture](docs/architecture/README.md) | Contracts of the module you are about to touch |
| 4 | [PC contract](docs/architecture/pc-contract.md) | Mandatory when the change talks to NB Sound on the PC |

If the work depends on a decision that has not been taken, **do not start**: raise the decision first.

## 3. Repository architecture

```text
docs/                 Single source of truth (Spanish). Start at docs/README.md
  adr/ architecture/ audit/ design/ developer/ institution/ legal/ user/ assets/
lib/
  app/                Root widget, tabs, keyboard shortcuts
  core/network/       **The only network exit.** Nothing connects from anywhere else
  core/i18n/          tr(), Spanish source text, English and Portuguese catalogues
  core/               DI, router, fuzzy search, keychain, utilities, platform flags
  data/               Drift schema, DAOs, migrations, contract DTOs, demo catalogue
  features/           sync, library, player, remote_control, offline, local_media,
                      lyrics, karaoke, equalizer, profile, about
  shared/             Theme and UI components
android/app/src/main/kotlin/   MediaStore, artwork cache, widgets, launcher alias, installer
ios/Runner/           iOS project (untested on a real device)
test/                 Mirrors lib/
tool/guardianes/      Guardians run by `just verify` and CI
```

## 4. Commands

| Command | Purpose |
|---|---|
| `just setup` | `flutter pub get` and code generation |
| `just run` / `just demo` | Run on a device; `demo` uses the fictional demo catalogue (`NB_SEED=true`) |
| `just test` | `flutter test` |
| `just guardianes` | All guardians |
| `just verify` | The full definition of done (section 7) |
| `just apk` | Release APKs (per ABI and universal) |

## 5. Non-negotiable rules

| Rule | Where it lives | Mechanism |
|---|---|---|
| Nothing leaves the device unless the person asks for it | `lib/core/network/salidas.dart` | Automatic: `tool/guardianes/red.dart` rejects any HTTP client, socket, WebSocket, remote image or remote audio outside `lib/core/network/`, and any connection in Kotlin |
| The app writes no logs | — | Automatic: `tool/guardianes/registro.dart` rejects `print`, `debugPrint`, `log` and `android.util.Log` |
| Every visible text is translated | `lib/core/i18n/` | Automatic: `tool/guardianes/i18n.dart` (missing, extra or mismatched placeholders) |
| Everything shipped is open and Apache-compatible | `pubspec.lock` | Automatic: `tool/guardianes/licencias.dart`; `THIRD-PARTY-NOTICES.md` must be current |
| No private keys, keystores or agent configuration in the repo | `.gitignore` | Automatic: `tool/guardianes/secretos.dart` |
| One version and one date everywhere | `pubspec.yaml`, `lib/core/plataforma.dart`, `CHANGELOG.md`, `CITATION.cff` | Automatic: `tool/guardianes/version.dart` |
| Docs have a title, a status label, working links, no emoji, no local paths, no pending work | `docs/` | Automatic: `tool/guardianes/docs.dart` |
| The PC owns its catalogue; the phone never edits it | [ADR-002](docs/adr/002-data-ownership.md) | Tests in `test/features/sync/` |
| Local phone music never reaches the PC | Negative ids | Tests in `test/features/player/` |
| A published migration is never edited | `lib/data/db/database.dart` | `test/data/migraciones_test.dart` upgrades from version 1 |
| Secrets live in the system keychain | `lib/core/security/secure_store.dart` | Review |
| No new dependency without justifying cost, licence and maintenance | [dependency policy](docs/architecture/dependency-policy.md) | Licence automatic; the rest in the pull request |

## 6. Privacy

* **No telemetry, analytics, crash reporting or usage tracking**, including "anonymous" or opt-out variants.
* **Two destinations only:** the paired PC and, on Android, the GitHub releases API when the person taps "Check for
  updates". A new destination is an ADR.
* **Secrets go to the keychain**, never to the database, preferences or logs.
* **No copyrighted media in the repository**, not even for tests or screenshots. The demo edition generates
  fictional covers, audio and lyrics on the device.

## 7. Verification

Run before declaring anything finished, without being asked:

```bash
just verify
# equivalent to:
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/guardianes/todos.dart
```

A change that touches packaging or native code is also checked with `flutter build apk --release`.

Definition of done:

1. The acceptance criterion is met and another person can check it.
2. Tests for the added logic and one regression test per fixed defect, named after the property they verify.
3. Verification is green.
4. If it has architectural or user-facing impact, `docs/` is updated in the same change.
5. If it adds visible text, its English and Portuguese translations are in the catalogues.

## 8. Language and style

* Spanish for identifiers, comments, `docs/` and commit messages; English for root community files and templates.
  Professional register, **no emoji** anywhere.
* Comments explain **why**, not what, and never narrate the history of the code.

## 9. Commits

```bash
git commit -s -m "feat(player): añadir temporizador al terminar la canción"
```

Conventional Commits, `-s` mandatory (DCO), body explaining why and what was verified.

## 10. What requires asking

* Approving or changing an ADR, adding a dependency or changing a licence.
* Publishing, pushing to a remote, or any outward-facing action.
* Anything that sends data off the device or contradicts this file or the Constitution.

## 11. One agent on the working tree

Two agentic tools must never write to this repository at the same time. If modifications appear that you do not
recognise, compare with `HEAD` (`git status`, `git show HEAD:<path>`) and restore from it; never trust the copy on
disk.
