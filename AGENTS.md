# Repository instructions for coding agents

## Start here

Read `README.md`, `docs/CONTRIBUTING.md`, `docs/DEPLOYMENT.md`,
`secrets/README.md`, and `docs/GITHUB_DEPLOYMENT.md` before changing this
repository. Also read `docs/HARNESS.md` when working on validation, builders,
or deployment procedures. Inspect
`git status` and preserve existing user changes. These instructions apply to
the whole repo.

## Current priorities and deferred work

- Iteration 2 targets Home Assistant, Mosquitto, Zigbee2MQTT, and Z-Wave JS
  with two LAN-connected PoE radios. Read `docs/ITERATION-2.md` before working
  on it. Obtain actual models/firmware/endpoints and migration requirements;
  do not guess hardware settings, reset radios, or invent network keys.
  Adam confirmed fresh networks and Home Assistant access over both LAN and
  Tailscale. Radio firmware/transport settings have explicit fill-in fields in
  the iteration plan; do not replace them with guessed defaults or deploy them.
- Matter and Thread are deferred. GitHub production deployment is also paused;
  do not implement/enable it as part of the home-automation work.
- When Adam asks to "revisit GitHub deployment", resume from the checkpoint in
  `docs/GITHUB_DEPLOYMENT.md` under "Paused work: resume GitHub deployment here".
  Recheck current code and prerequisites rather than assuming provisioning.

## Pull requests and production boundary

- Treat `main` as production: merging is intended to trigger a real rebuild
  and deployment after checks pass. The deployment workflow is not implemented
  yet; never confuse current fixture CI with production deployment.
- Use feature branches and PRs for every change, including docs and workflows.
  Adam Arbour (`@adamarbour`) is the sole reviewer and approver, and only Adam
  may merge.
- Never push directly to `main`, approve/merge a PR, enable auto-merge, bypass
  review, or change GitHub protections. Do not commit, push a branch, or open a
  PR without authorization. Passing checks does not replace Adam's approval.
- Include validation, production impact, rollback, and reboot requirements in
  the PR. New commits require renewed review. Follow `docs/GITHUB_DEPLOYMENT.md`
  for the human/agent workflow and GitHub's self-approval limitation.
- Adam's merge authorizes only the routine activation defined by the eventual
  deployment workflow, not ad hoc agent deployment or reboot commands.

## Architecture and safety invariants

- This is one NixOS host, `arbour-haus`, exposed through a plain flake. Do not
  introduce Home Manager, flake-parts, deployment frameworks, or additional
  hosts unless requested.
- All external Nix sources must be hash-pinned in `flake.lock`. Reuse the pinned
  stable nixpkgs library; do not use channels, `<nixpkgs>`, registries, unlocked
  fetches, or `builtins.getFlake` in project code. Upstream library internals
  are not handwritten project code.
- Files under `modules/` are ordinary NixOS modules, explicitly imported by
  `hosts/arbour-haus/configuration.nix`. Keep hardware settings in the host's
  `hardware.nix`, and helpers/tests outside production imports. Avoid automatic
  discovery and unnecessary abstractions.
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
   Follow the evidence levels in `docs/HARNESS.md`; never infer build success
   from builder configuration, derivation evaluation, or an unrelated `result`.
7. Deployment documentation must distinguish destructive first installation
   from routine updates. Preserve the exact-candidate build gate, SSH recovery,
   rollback, and reboot acceptance in both Git and Git-free workflows. Never
   require Git on a target receiving only a prebuilt closure, or imply that
   transferring a closure also updates its persisted source checkout.

If tooling, hardware, secrets, or target settings prevent a check/build, state
that plainly. Never claim "deployable", "tested", or "working" beyond the
validation actually performed. Do not commit or push unless asked.
