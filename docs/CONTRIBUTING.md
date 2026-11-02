# Engineering standards

## Pull requests and approval

Follow [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) for every change. Work on a
feature branch and open a PR to `main` when authorized; never push directly to
`main`. Adam Arbour is the sole reviewer and approver, and only Adam merges.
Neither an AI agent nor a passing check may substitute for his approval.
Treat the merge as a production rebuild/deployment trigger under the planned
automation, including for documentation-only changes. Current CI is still
fixture validation, not production deployment. Branch protections and required
reviews must be configured separately; documentation does not enforce them.

## Design

Keep changes declarative and scoped to the single host. `flake.nix` exposes
`nixosConfigurations.arbour-haus`; ordinary NixOS modules under `modules/` are
explicitly imported by `hosts/arbour-haus/configuration.nix`. Hardware settings
belong in the host's `hardware.nix`. No auto-discovery, flake-parts, Home Manager,
or deployment framework is needed.

Prefer upstream options and service hardening defaults over activation scripts.
Use `lib.mkDefault` only for intended override points; avoid `mkForce` unless
the conflict and reason are documented.

Every external source is hash-pinned in `flake.lock`. Dependencies needing
nixpkgs follow the root stable input. Impermanence is source-only so its unused
development inputs do not add Home Manager or another nixpkgs. Do not use
channels, registries, `<nixpkgs>`, or unlocked fetches in project code.

Review upstream compatibility when updating dependencies. Nixpkgs stays on the
selected stable release unless a release migration is requested.
`system.stateVersion` is an installation compatibility contract, not an update
counter. The planned normal update path is Adam-reviewed PRs followed by a
merge-triggered build/deployment. Until implemented, use the documented manual
procedures with explicit authorization; never infer activation from a merge.

## Stateful features

For each service, document and test:

- Exact writable state paths, merged narrowly into
  `environment.persistence."/persist"`. Do not persist whole `/etc`, `/var`, or
  `/home` trees as a workaround.
- Required users/groups and ownership/modes.
- Runtime secret paths and ordering. First-boot identities must be provisioned
  before consumers run; no secret is currently required for first boot.
- Network exposure and authentication. Open only needed ports; do not weaken
  upstream sandboxing or grant unnecessary privileges.
- Backup/restore and migrations. Generation rollback does not roll back data.

Tailscale's root-only `/var/lib/tailscale` contains private node identity and
preferences. Back it up securely or re-enroll after its loss; never start two
machines with the same restored identity. Enrollment is interactive over LAN,
with no auth key in Git, Nix, logs, or fixtures. Tailnet grants/ACLs must limit
SSH to intended administrators. Tailscale SSH stays disabled.

Private identities stay outside the repository. Encrypted payloads go only in
`secrets/`. SOPS metadata and filenames are public. Ignore rules are not a
secret scanner: inspect all diffs and untracked files before committing.

## Harness standards

See [HARNESS.md](HARNESS.md) for script contracts, Linux builder preflight,
agent reporting requirements, and recorded build/installation status. Keep those
contracts synchronized with script changes. Documentation-only changes still
run `./scripts/check.sh`; they do not require a fresh system build unless a
new deployment candidate is being claimed.

Deployment procedures must support both a persisted Git checkout and manual
transfer of an exact prebuilt closure. The latter requires no target-side Git
or reevaluation. Both retain the build gate, root the candidate against GC,
record the previous generation, and require explicit activation and reboot
permission. A closure transfer does not synchronize source or persistent data.
See [DEPLOYMENT.md](DEPLOYMENT.md).

## Validation

```sh
./scripts/check.sh                  # pinned formatting + shell lint + fixture eval
./scripts/check.sh --deployment     # additionally evaluate real host assertions
./scripts/build.sh                  # same gates + real Linux system build
```

Scripts work from any directory, use `path:<checkout>` to include new files
without staging, and refuse lock changes. Enable `nix-command flakes` in your
workstation's Nix configuration. The first run needs network/cache access.

Format with `nix develop --command nixfmt <changed-files>`. Before standard
Git-flake commands, add new files to Git; otherwise Nix cannot see them.
`nix flake check --no-build` also evaluates the real host output, so unlike the
default check script it requires valid operator settings. `nix flake check`
on x86_64 Linux additionally builds the fixture system and disko script.

`tests/eval.nix` checks storage, persistence, security, Tailscale, source policy,
and full derivation evaluation with isolated settings. Missing-setting checks
must not depend on the operator's real `host-settings.nix`. Test-only keys and
disks are deliberately unusable. Fixtures are exposed only through checks,
not installation or production entry points.

GitHub Actions runs lint/evaluation and builds
`checks.x86_64-linux.fixture-system` and `fixture-disko`, using commit-pinned
actions. This existing validation workflow never activates, formats disks,
enrolls Tailscale, or uses private keys. The separately planned production
workflow must follow [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md). A fixture
build does not certify the target hardware.

Update regression tests with features. Home Assistant and empty-secret checks
must evolve when those features are intentionally enabled, not be removed to
hide failures. Add runtime/VM coverage where possible.

## Completion report

Report changes, validation commands/results, deployment artifact if any,
remaining prerequisites, and migration/rollback risks. Distinguish:

1. Formatting/lint passed.
2. Evaluation passed (no Linux packages built).
3. Fixture system built (not the target configuration).
4. Real system built (`result-deploy`, not activated).
5. Activated and reboot/health checks passed (requires authorization).

Missing settings or an unavailable Linux builder blocks level 4; fixtures are
not a substitute. Boot/storage/access/persistence changes require the runtime
acceptance procedure before claiming runtime verification. Never deploy,
commit, or push without explicit authorization.
