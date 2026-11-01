# Repository instructions for coding agents

## Start here

Read `README.md`, `docs/CONTRIBUTING.md`, `docs/DEPLOYMENT.md`, and
`secrets/README.md` before changing this repository. Inspect `git status` and
preserve existing user changes. These instructions apply to the whole repo.

## Architecture and safety invariants

- This is one NixOS host, `arbour-haus`. Do not introduce flakes, Home Manager,
  deployment frameworks, or additional hosts unless requested.
- All external Nix sources must be hash-pinned through npins. Reuse the pinned
  stable nixpkgs library; do not use channels, `<nixpkgs>`, registries, unlocked
  fetches, or `builtins.getFlake` in project code. The generated npins loader
  and upstream library internals are not handwritten project code.
- Every `.nix` file under `modules/` is a flake-parts module. Declare features
  through `flake.modules.nixos.<name>` and compose them in `modules/host.nix`.
  Put helpers/tests outside that auto-imported tree. Avoid unnecessary abstractions.
- Root is ephemeral tmpfs. `/nix`, `/persist`, and `/boot` survive reboots.
  Every new stateful feature must explicitly declare narrowly scoped persistence,
  ownership, permissions, backup requirements, and secret dependencies.
- Keep all secret payloads SOPS-encrypted under `secrets/`. Never put plaintext
  secrets or private keys in Git, Nix expressions, derivations, logs, or fixtures.
  Consume secrets through runtime paths; never `builtins.readFile` a secret.
- Preserve SSH-key-only administration, stable host identity, and early access
  to the persisted sops-nix identity. Do not remove access assertions to make a
  build pass. Keep test-only settings strictly out of production entry points.
- Never run disko, install, activate, reboot, rotate identities, or deploy without
  explicit permission. Build/evaluation commands are not deployment permission.
- Do not update pins, change disk layout, or bump `system.stateVersion` as an
  unrelated cleanup. Explain migration and rollback implications when relevant.

## Required workflow / definition of done

1. Implement a complete, coherent change; no broken imports, stub features,
   unexplained placeholders, or disabled safety checks. Existing installation
   placeholders in `host-settings.nix` must be filled by the operator, not guessed.
2. Update tests and relevant docs in the same change. Tests must still pass after
   an operator fills in the real host settings; use isolated fixtures.
3. Format handwritten Nix with the pinned `nixfmt`, and run `./scripts/check.sh`.
4. For a deployment candidate, run `./scripts/build.sh` with the real settings on
   a matching Linux builder. It must pass checks and produce `result-deploy`.
   A fixture build or `.drvPath` evaluation is **not** a deployment candidate.
5. For boot, storage, persistence, access, or secret-ordering changes, require
   the reboot/health acceptance checks in `docs/DEPLOYMENT.md` on a disposable
   VM or the authorized target before claiming runtime verification.
6. Inspect the final diff. Report what changed, commands run/results, artifact
   path if built, and any remaining operator actions or untested behavior.

If tooling, hardware, secrets, or target settings prevent a check/build, state
that plainly. Never claim "deployable", "tested", or "working" beyond the
validation actually performed. Do not commit or push unless asked.
