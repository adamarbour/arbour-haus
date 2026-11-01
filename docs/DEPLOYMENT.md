# Deployment acceptance and recovery

## What counts as a deployable working copy

A candidate is the **real host configuration** with operator-supplied disk and
SSH keys, passing `./scripts/build.sh` on a matching Linux builder (or via an
explicitly configured remote builder). Success produces the `result-deploy`
symlink to a realized NixOS system closure. The script never formats, activates,
or reboots anything. It removes a previous candidate symlink at the start, so a
failed run cannot leave that old link looking like a new successful build.

An evaluation, CI fixture build, stale build link, or placeholder configuration
is not a deployment candidate. The initial scaffold intentionally blocks real
builds until `host-settings.nix` is completed. No tooling can certify hardware
bootability without booting it; do not equate a successful build with a tested
system. CI validates the fixture only, without production secrets.

## Preflight checklist

- Read `README.md` and `secrets/README.md`; confirm target architecture, UEFI
  support, disk identity, public keys, and reachable SSH/console access.
- Review the entire diff and pin changes. Keep configuration and encrypted
  secrets in a reproducible reviewed revision; do not deploy concurrent edits.
- Back up `/persist` and the host SSH identity securely off-machine. Check any
  service data migration plan. NixOS rollback does not revert disk/application
  data, and impermanence does not replace backups.
- For a fresh installation, build successfully **before** the destructive disko
  step in `README.md`. Never rerun disko for an ordinary update.
- Run `./scripts/build.sh` with real settings. On macOS, stop at
  `./scripts/check.sh --deployment` unless a Linux remote builder is configured;
  explicitly report that a real build is still required.

## Routine activation (operator authorization required)

On the target, in the persisted `/etc/nixos` checkout:

```sh
./scripts/build.sh
candidate=$(readlink result-deploy)
# Inspect the change before updating the system profile:
nix-store --query --requisites "$candidate" >/dev/null
sudo nix-env --profile /nix/var/nix/profiles/system --set "$candidate"
sudo "$candidate/bin/switch-to-configuration" switch
```

This activates the exact closure built by the gate, rather than reevaluating
possibly changed files. Keep the current SSH session open and verify a second
connection before closing it. For routine manual use, the legacy
`nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix` bridge is
also available, but it rebuilds from the working tree; it is not an activation
of a previously reviewed artifact. Do not change the checkout during a build.

## Runtime acceptance

After activation, and again after an explicitly authorized reboot:

1. Verify SSH login and sudo; confirm host key fingerprints did not change.
2. Run `systemctl --failed`; investigate any failed units. Check changed services
   with `systemctl status <unit>` and `journalctl -b -u <unit>`.
3. Confirm `findmnt /` is tmpfs and `/nix`, `/persist`, `/boot` are mounted as
   expected. Confirm `/etc/nixos/configuration.nix` is available.
4. Perform the persistence smoke check in `README.md`: an unlisted root marker
   disappears while the `/persist` marker, machine-id, and host keys survive.
5. When secrets are configured, verify consumers start and the expected runtime
   files exist with correct owner/mode. Do not print plaintext secret values.
6. When stateful services are enabled, create representative state, reboot,
   and verify that state and service functionality survive. Exercise their
   backup/restore procedure before relying on them.

Boot/storage/persistence changes require these checks on a disposable VM or the
authorized target. Record the revision, closure store path, platform, checks
performed, failures, and outstanding risks in the change/PR or session handoff.

## Recovery

Before activation, note the current generation (`sudo nix-env --profile
/nix/var/nix/profiles/system --list-generations`). If the new system is unhealthy:

```sh
sudo nixos-rebuild switch --rollback
```

If it cannot boot or SSH is unavailable, use the console to select the prior
boot generation. Filesystem layout changes may require installer media and
manual recovery; an older generation cannot undo repartitioning. Restore
persistent data from backups only with services stopped and the correct
ownership/modes. Retain the known-good generation until acceptance is complete;
automatic GC is configured to remove generations older than 30 days.
