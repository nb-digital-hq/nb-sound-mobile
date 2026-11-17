# Contributing to NB Sound Mobile

Thank you for your interest. The project documentation is in Spanish, under [`docs/`](docs/README.md). If you work
with an AI coding agent, point it to [AGENTS.md](AGENTS.md): it contains the same rules in one place.

## Before writing code

1. Read the [product philosophy](docs/design/product-philosophy.md) and the
   [Constitution](docs/architecture/constitution.md). A technically correct contribution that contradicts them will
   be declined.
2. Look for an existing issue. If there is none, open one before implementing.
3. For changes with architectural impact, propose an ADR first ([ADR index](docs/adr/README.md)).

## Licence and provenance

NB Sound Mobile is released under the **Apache License 2.0**. Your contribution is licensed under the same terms
and **you keep your copyright**: there is no copyright assignment and no contributor licence agreement.

The only requirement is the Developer Certificate of Origin (DCO): every commit carries a `Signed-off-by` line.

```bash
git commit -s -m "fix(player): conservar la cola al traspasar al PC"
```

If you forgot to sign off, `git rebase --signoff origin/main` fixes the commits on your branch.

## Workflow

1. Fork the repository and create a branch: `feat/short-description` or `fix/short-description`.
2. Make atomic commits following [Conventional Commits](docs/developer/commit-convention.md).
3. Run `just verify` (format, analysis, tests and guardians; see [setup](docs/developer/setup.md)).
4. Open the pull request against `main` and complete the template.

## What is not accepted

* Third-party code without a compatible licence or without attribution.
* Telemetry, analytics, advertising, logging or any network connection outside `lib/core/network/`.
* Closed-source or GPL-family components in the app ([dependency policy](docs/architecture/dependency-policy.md)).
* Copyrighted music, covers or lyrics, including as test material. Use the demo edition (`NB_SEED=true`).
* User-visible text without its English and Portuguese translations.

## Conduct and security

All interactions are governed by the [Code of Conduct](CODE_OF_CONDUCT.md). **Do not report vulnerabilities as
public issues**; see [SECURITY.md](SECURITY.md).
