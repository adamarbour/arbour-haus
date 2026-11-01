# Engineering standards

## Design

Keep changes small, declarative, and scoped to the single host. Feature files
under `modules/` are flake-parts modules defining named NixOS modules, not bare
NixOS imports. The host opts into each feature explicitly. Prefer upstream
NixOS options and service hardening defaults over custom activation scripts.
Use `lib.mkDefault` only for intended override points; avoid `mkForce` unless
the conflict and reason are documented.

Use npins for every external Nix dependency. Commit its source hashes and
review upstream compatibility when updating pins. Use the shell's npins so the
lock format stays compatible with stable nixpkgs' tooling. Do not hand-edit the generated
`npins/default.nix`. Nixpkgs updates stay on the selected stable release unless
a release migration is explicitly requested. `system.stateVersion` is an
installation compatibility contract, not a version to bump with dependencies.

## Stateful features

For each service, document and test:

- Its exact writable state directories and persistence needs. Merge narrowly
  scoped entries into `environment.persistence."/persist"` from the feature.
- Required users/groups and directory ownership/modes. Do not broadly persist
  `/etc`, `/var`, or `/home` to make a service work.
- Runtime secret paths and startup ordering. Required first-boot identities
  must exist on persistent storage before activation.
- Network exposure: open only required ports, explain authentication, and avoid
  weakening upstream sandboxing or granting unnecessary root privileges.
- Backup/restore, data migrations, and whether old software can read new state.
  Rolling back a NixOS generation does not roll back application data.

Private identities stay outside the repository. Encrypted payloads go only in
`secrets/`. SOPS metadata and filenames are public. Git ignore rules are not a
secret scanner; inspect every diff, including untracked files, before committing.

## Validation

```sh
./scripts/check.sh                  # pinned formatting + shell lint + eval
./scripts/check.sh --deployment     # also evaluate real host build assertions
./scripts/build.sh                  # same gates + real Linux system build
```

The scripts can be run from any directory. The check gate always enters
`shell.nix` to use pinned lint tools and checks that its npins can read the lock
format. Project Nix source resolution is pinned, independent of `NIX_PATH`.
A first run requires network access to fetch the pins and binary tools.
To format handwritten Nix, enter `nix-shell` and run `nixfmt <changed-files>`.
Generated `npins/default.nix` is intentionally excluded from formatter checks.

`tests/eval.nix` validates security, storage, persistence, host composition, and
full derivation evaluation using an isolated, deliberately unusable SSH key.
`tests/legacy.nix` checks the real legacy rebuild bridge without requiring valid
installation settings. `tests/build.nix` exposes the fixture system for CI to
actually build Linux packages; it is never an installation entry point.

GitHub Actions runs these checks and builds the fixture system and disko script
on x86_64 Linux. Actions are commit-pinned. CI does not possess private keys,
activate a system, format disks, or assert that the real hardware boots.

Update regression tests as features are enabled. Tests that currently assert
Home Assistant is disabled or that no secrets are declared must evolve with
those features; do not delete meaningful coverage merely to get a green run.
Add runtime/VM tests when possible for behavior evaluation cannot verify.

## Completion report

Summarize the change, test commands and outcomes, deployment artifact (if any),
remaining prerequisites, and migration/rollback risks. Distinguish:

1. Formatting/lint passed.
2. Evaluation passed (derivations constructed, no packages built).
3. Fixture system built (CI, not real deployment settings).
4. Real system built (`result-deploy`, not activated).
5. Activated and reboot/health checks passed (requires authorization).

Missing host settings or an unavailable Linux builder is a blocker to level 4,
not a reason to substitute fixtures or claim deployment readiness. Every change
must leave a coherent validated working tree; runtime readiness requires the
separate deployment acceptance procedure.
