## Problem

<!-- Link the issue or the ADR. -->

Closes #

## Approach

<!-- One or two sentences about the approach, not a summary of the diff. -->

## How to verify

<!-- Manual steps, or the name of the added test. -->

---

## Definition of done

See [`AGENTS.md`](../blob/main/AGENTS.md), section "Verification".

- [ ] The acceptance criterion is met and can be checked by another person
- [ ] There are tests for the added logic, and one regression test per fixed defect
- [ ] `just verify` passes
- [ ] New visible text has its English and Portuguese translations
- [ ] If it has architectural or user-facing impact, `docs/` was updated in this same pull request
- [ ] Commits are signed off with `git commit -s` (DCO)

## Impact

- [ ] Adds or changes dependencies <!-- justify per docs/architecture/dependency-policy.md -->
- [ ] Changes the database schema <!-- include a migration and extend the migration test -->
- [ ] Affects personal data or anything that leaves the device
- [ ] None of the above
