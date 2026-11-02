# Deployment acceptance and recovery

## GitHub merge and approval policy

**Merging into `main` is intended to trigger a real rebuild and deployment
after successful checks.** Every change must arrive through a feature branch
and PR. Adam Arbour is the sole reviewer and approver, and only Adam may merge.
Humans and agents must treat that merge as a production action, not just source
synchronization. See [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) for required
reviews, agent restrictions, GitHub enforcement setup, and the planned pipeline.

Current Actions only runs validation/fixture builds. The production workflow
and repository protections are not enabled by these docs. Until automation is
implemented and verified, the manual procedures below require explicit operator
authorization. Once enabled, Adam's approved merge authorizes the workflow's
routine activation only; destructive operations, identity changes, and reboots
remain separately authorized. Manual procedures remain recovery/fallback paths,
not a way to bypass review for normal updates.

## What counts as a deployment candidate

The **real host configuration**, with operator-supplied disk and SSH keys,
must pass `./scripts/build.sh` on a matching Linux builder (or an explicitly
configured remote builder). Success produces `result-deploy`, a GC-rooted
symlink to the realized system closure. The script never formats, installs,
activates, or reboots. It removes an earlier candidate link at the start so
failure cannot leave that link looking like a new successful build.

Evaluation, CI fixtures, placeholder settings, and stale links are not
candidates. Building alone does not establish bootability. On macOS, stop at
`./scripts/check.sh --deployment` unless a Linux builder is configured.

## Initial deployment (fresh installation only)

This procedure runs on the **target's NixOS installer**, not on the macOS
workstation or its builder VM. It erases the selected target disk. A builder
only realizes artifacts; it is not automatically the machine to install.
See [HARNESS.md](HARNESS.md#build-and-installation-status) for build history
and operator-reported installation status. Always stop unless the real-host
build gate succeeds for the candidate being installed.

1. Back up existing disk contents. Boot a NixOS installer with Git available
   in **UEFI** mode, connect it to the LAN, and become root. Verify
   `/sys/firmware/efi` exists. Enable flakes for the installer session:

   ```sh
   export NIX_CONFIG='experimental-features = nix-command flakes'
   ```

2. Clone your reviewed repository to `/tmp/arbour-haus` and select the reviewed
   revision. From that directory, review `host-settings.nix`: confirm
   `x86_64-linux`, your actual public admin key, and the disk's exact by-id path
   against `lsblk` and `/dev/disk/by-id`. Review the target's
   `nixos-generate-config --show-hardware-config` output and incorporate needed
   drivers in `hosts/arbour-haus/hardware.nix`, not its filesystem entries.
   Do not reuse a CI fixture disk or key. Record the reviewed revision and any
   local changes; reconcile them before treating the source as reproducible.

3. Build the real configuration on the installer (or use a configured matching
   Linux builder). **Stop on any error.** Record the resulting closure:

   ```sh
   cd /tmp/arbour-haus
   ./scripts/build.sh
   candidate=$(readlink result-deploy)
   printf '%s\n' "$candidate"
   ```

4. Independently recheck the configured disk immediately before proceeding.
   **Only with explicit permission to erase that disk**, build and run disko
   from this same unchanged source. This is never an ordinary update step:

   ```sh
   nix build --no-update-lock-file \
     "path:$PWD#nixosConfigurations.arbour-haus.config.system.build.diskoScript" \
     --out-link result-disko
   ./result-disko
   ```

5. Copy the reviewed checkout into persistent backing storage and install the
   exact successful candidate. `/mnt/etc` itself is ephemeral. No SOPS payload
   is needed for this baseline; if adding first-boot secrets, provision their
   persisted identity first as described in [secrets](../secrets/README.md).

   ```sh
   mkdir -p /mnt/persist/etc/nixos
   cp -a /tmp/arbour-haus/. /mnt/persist/etc/nixos/
   chown -R root:root /mnt/persist/etc/nixos
   nixos-install --system "$candidate" --no-root-passwd
   ```

6. With separate reboot authorization, reboot into the installed system.
   Connect as `admin` using the configured private key and verify the host
   fingerprint through a trusted channel. There is no password fallback.
   Enroll Tailscale over LAN using the [README procedure](../README.md#tailscale-enrollment).
   Complete [runtime acceptance](#runtime-acceptance), including a second
   authorized reboot, before relying on persistence or remote access.

For later Git-free updates, use the prebuilt-closure procedure below. It does
not rerun disko or `nixos-install`.

## Preflight

- Review `README.md`, target architecture, UEFI support, hardware settings,
  disk identity, and public SSH keys. Have a LAN SSH recovery path and a plan
  for physical/installer access if neither SSH path works.
- Review the complete source revision and lock changes on the build machine.
  Keep configuration and encrypted secrets in a reproducible reviewed revision
  or securely retained source snapshot. Git-free target updates still need
  source provenance. Do not edit or pull concurrently with a build.
- Back up `/persist` securely off-machine, including host keys, Tailscale
  state, and the checkout. Review data migration and restore plans. Impermanence
  does not replace backups, and generation rollback does not restore data.
- For a fresh installation, successfully build **before** disko. Verify the
  exact disk independently. Never run disko for an ordinary update.
- Run `./scripts/build.sh` using the real host settings.

## Routine update and activation (operator authorization required)

In the target's persisted checkout:

```sh
cd /etc/nixos
sudo git status --short             # stop if there are unresolved local changes
sudo git pull --ff-only             # reviewed revision; no unattended deployment
sudo ./scripts/build.sh
candidate=$(readlink result-deploy)

# Record revision, closure and current generation before activation.
sudo git rev-parse HEAD
printf '%s\n' "$candidate"
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
nix-store --query --requisites "$candidate" >/dev/null
sudo nix-env --profile /nix/var/nix/profiles/system --set "$candidate"
sudo "$candidate/bin/switch-to-configuration" switch
```

This activates exactly the built closure without reevaluating the checkout.
Keep the existing SSH session open and establish a second connection before
closing it. Prefer LAN access when changing Tailscale; tailscaled may restart
on updates. There is no automatic pull, dependency update, activation, or
reboot service.

For manual use, `sudo nixos-rebuild switch --flake /etc/nixos#arbour-haus` is
available, but reevaluates/rebuilds the current checkout rather than activating
a previously reviewed artifact. The npins/legacy `configuration.nix` entry
points have been removed.

## Manual redeployment without Git on the target

Build on the workstation's existing Git checkout using its Linux builder, or
on another matching Linux build machine. The target only receives the exact
realized closure: no pull, source evaluation, dependency update, or rebuild
runs there. This is a routine update, **not** a fresh installation; never run
disko or `nixos-install` here.

### 1. Build and record the candidate (build machine)

Review the preflight above, including target settings and backups. Run from
the unchanged source checkout:

```sh
./scripts/build.sh
candidate=$(readlink result-deploy)
test -x "$candidate/bin/switch-to-configuration"
printf '%s\n' "$candidate"
git rev-parse HEAD
git status --short
```

Stop unless the build succeeds. Retain the reviewed source, lock file, local
diff if any, and closure path in your deployment record. Keep `result-deploy`
rooted. Source snapshots can contain encrypted secrets but must never contain
private keys or plaintext secrets. macOS requires the configured x86 Linux
builder; an evaluation alone is insufficient.

### 2. Transfer and root the complete closure (build machine)

Set `target` to the verified LAN or Tailscale SSH destination. First confirm
its host fingerprint and key-only login. The existing admin account has
passwordless sudo; these commands use `sudo -n` so they fail rather than hang
on a password prompt. Do not enable root SSH or weaken host-key checking.

The pipeline exports every requisite and imports it through the target's
root-owned Nix store. This avoids requiring a trusted remote Nix user or Git
on the target. Run in Bash with `pipefail`; ensure both ends have enough
persistent `/nix` space. Transferring/rooting a candidate is not activation,
but it does modify the target store and needs operator approval.

```sh
set -euo pipefail
target=admin@192.0.2.10  # replace with the actual verified target
ssh "$target" 'sudo -n true; uname -m; df -h /nix /persist'
# Check that uname reports x86_64 for this configured host.
nix-store --export $(nix-store --query --requisites "$candidate") | \
  ssh "$target" "sudo -n nix-store --import >/dev/null &&
    sudo -n nix-store --realise '$candidate' \
      --add-root /nix/var/nix/gcroots/arbour-haus-candidate"
```

The unquoted command substitution intentionally supplies each requisite as
an argument; Nix store paths contain no whitespace. The candidate comes from
`readlink result-deploy`, not arbitrary shell input. Stop if either side fails.
If the GC-root path already exists, first inspect it and retain any candidate
you still need under a separate root; remove only that old symlink before
retrying. Never delete its store path or replace an unknown file/directory.
Do not run GC concurrently with import/rooting. This transfer does not copy
`/persist`, provision secret identities, enroll Tailscale, or update
`/etc/nixos`.

### 3. Activate exactly that candidate (target, authorization required)

Keep the original SSH session open and have a LAN/console recovery path.
Open a target shell and set `candidate` to the **exact store path recorded
above**; do not guess it from an unrelated `result` link.

```sh
candidate=$(readlink /nix/var/nix/gcroots/arbour-haus-candidate)
test -x "$candidate/bin/switch-to-configuration"
printf 'Candidate: %s\n' "$candidate"
printf 'Currently running: %s\n' "$(readlink -f /run/current-system)"
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
sudo nix-store --query --requisites "$candidate" >/dev/null
# Only after reviewing the paths and with activation authorization:
sudo nix-env --profile /nix/var/nix/profiles/system --set "$candidate"
sudo "$candidate/bin/switch-to-configuration" switch
```

Record the previous generation and running closure **before** changing the
profile. Establish a second SSH connection before closing the first. Run the
runtime acceptance below; reboot only with separate permission. If activation
fails, do not reboot blindly: inspect the logs and use the recovery procedure.
Keep the known-good generation until acceptance passes. After acceptance the
system profile roots the candidate; its extra GC-root symlink may be removed
with operator approval. Keep the build-machine root until transfer is verified.

### Source and secrets after a Git-free update

The persisted `/etc/nixos` checkout is **unchanged** and may now be stale.
Do not run `nixos-rebuild` against it unless intentionally returning to that
source. Keep reviewed source and provenance off-host, or synchronize a reviewed
snapshot separately with explicit permission and backups. Do not blindly
extract an archive over the live root or `/persist`. Embedded encrypted SOPS
files travel with their Nix closure, but decryption still requires the target's
correct persisted identity and documented runtime ordering.

Rollback does not require Git: `sudo nixos-rebuild switch --rollback` uses the
previous system generation. It does not restore source, secret identities, or
application data. Retain the previous closure and secure persistence backups.

## Runtime acceptance

After activation, and again after an explicitly authorized reboot:

1. Verify key-only SSH and sudo over LAN and from an authorized tailnet client.
   Confirm host fingerprints are unchanged. Verify unwanted tailnet clients
   cannot access SSH according to your tailnet policy.
2. Run `systemctl --failed`; inspect any failures. Check `sshd`, `tailscaled`,
   and `tailscaled-set` status/journals. Before enrollment, an unauthenticated
   Tailscale node is expected; LAN SSH must still work. After enrollment,
   `sudo tailscale status` should show the same node and address after reboot.
3. Confirm tmpfs `/` and persistent mounts:

   ```sh
   findmnt /
   findmnt /nix
   findmnt /persist
   findmnt /boot
   sudo test -f /etc/nixos/flake.lock
   sudo test -d /etc/nixos/.git
   sudo stat -c '%U:%G %a' /var/lib/tailscale  # root:root 700
   ```

4. Perform a real persistence smoke check. Record the identity values before
   reboot and compare after reconnecting; do not print private identities:

   ```sh
   cat /etc/machine-id
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   sudo tailscale ip -4  # after enrollment
   sudo touch /persist/persistence-check
   sudo touch /root/ephemeral-check
   # Only with explicit authorization:
   sudo reboot
   # After reconnecting:
   sudo test -e /persist/persistence-check
   sudo test ! -e /root/ephemeral-check
   sudo rm /persist/persistence-check
   ```

5. When secrets are added, verify runtime files and ownership/modes without
   printing their contents. Verify consumers start after decryption.
6. When stateful services are added, create representative state and verify it
   survives reboot. Exercise their backup/restore procedure before relying on
   them. Home Assistant is not enabled in this iteration.

Boot/storage/persistence/access changes need these checks on a disposable VM
or the authorized target. Tailnet connectivity requires a real enrollment and
policy test; evaluation cannot establish it. Record the revision, closure,
platform, checks performed, and remaining risks.

## Recovery

For an unhealthy activation while SSH still works:

```sh
sudo nixos-rebuild switch --rollback
```

Also restore the checkout to a known-good reviewed revision before the next
build; generation rollback does not change Git. If only Tailscale fails, use
LAN SSH. If neither SSH path works, use physical/installer access to select the
prior boot generation or repair the configuration. Normal administration is
SSH-only, but no configuration can guarantee remote recovery from every boot
or networking failure.

Generation rollback cannot undo disk formatting or application migrations.
Restore persistent data with consumers stopped and correct ownership/modes.
Restore SSH keys to retain trusted host fingerprints and the SOPS recipient;
otherwise verify new fingerprints and re-encrypt using an operator identity.
Restore Tailscale state only for this same host with tailscaled stopped, or
re-enroll and remove the obsolete node from the tailnet. Never clone its active
identity onto a second machine. Treat private identity backups as secrets.

Retain a known-good generation until acceptance completes. Automatic GC
removes generations older than 30 days; it is not a backup or recovery plan.
