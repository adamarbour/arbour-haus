# Deployment acceptance and recovery

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

## Preflight

- Review `README.md`, target architecture, UEFI support, hardware settings,
  disk identity, and public SSH keys. Have a LAN SSH recovery path and a plan
  for physical/installer access if neither SSH path works.
- Review the complete Git revision and lock changes. Ensure configuration and
  encrypted secrets are committed to a reproducible reviewed revision. Do not
  edit or pull concurrently with a build.
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
