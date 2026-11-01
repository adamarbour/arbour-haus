# arbour-haus

Single-host, non-flake NixOS configuration for a future Home Assistant server.
Home Assistant is **not enabled yet**.

- **npins** locks all sources in `npins/sources.json`, including the stable
  **NixOS 26.05** channel. No `flake.nix`, `flake.lock`, registry, or experimental
  Nix features are needed.
- **flake-parts** is called as an ordinary Nix library with the pinned nixpkgs
  library. The `flake.*` option names are just its module API, not flake usage.
- **Dendritic modules:** every `.nix` file in `modules/` is automatically imported
  as a flake-parts module. Features define `flake.modules.nixos.<feature>`;
  `modules/host.nix` composes them into the sole host, `arbour-haus`.
- **disko:** one GPT disk, 512 MiB EFI system partition, and a Btrfs partition
  with separate `/nix` and `/persist` subvolumes. No swap or disk encryption.
- **Impermanence:** `/` is tmpfs, empty on each boot. Only explicitly declared
  state is kept under `/persist`; `/nix` and `/boot` also survive reboots.
- **sops-nix:** ready for age encryption using the host SSH identity. All
  encrypted payloads live in `secrets/`; none are required to boot.

## Layout

```text
default.nix             # npins -> flake-parts -> nixosConfigurations
configuration.nix       # legacy nixos-rebuild bridge to the same host module
host-settings.nix       # deployment-specific architecture, disk and public keys
lib/import-tree.nix     # recursive module discovery
modules/                # host composition and feature modules
npins/                  # generated source loader and committed pins
secrets/                # encrypted payloads and setup instructions
shell.nix               # pinned npins, sops, age, ssh-to-age and nixfmt
tests/                  # fixture evaluation/build and legacy bridge checks
scripts/check.sh        # pinned formatter, shell lint and evaluation gate
scripts/build.sh        # real host build -> result-deploy (never activates)
AGENTS.md               # repository-wide instructions for future coding agents
docs/                   # engineering standards and deployment acceptance
```

## Configure the target

Edit `host-settings.nix`:

1. Confirm `system` (defaults to `x86_64-linux`). The current boot setup assumes
   a generic PC/VM with **UEFI**, not a Raspberry Pi or BIOS-only machine.
2. Set `disk` to the correct persistent `/dev/disk/by-id/...` path, inspected
   with `lsblk` and `ls -l /dev/disk/by-id` on the target.
3. Add your actual SSH public key to `adminAuthorizedKeys`.
4. Review `modules/host.nix` for hardware-specific requirements. Inspect
   `nixos-generate-config --show-hardware-config` on the target and incorporate
   relevant kernel/platform settings there. Do not duplicate its filesystem
   entries: disko owns those.

Missing disk/key values intentionally fail NixOS build assertions. DHCP, UTC,
SSH-key-only access as `admin`, passwordless sudo for wheel, and a firewall
allowing SSH are the baseline. Root login is disabled. Protect the admin key;
it grants root-equivalent access. Reserve the host address in your DHCP server
if desired; the hostname alone does not guarantee LAN DNS resolution.

## Check and build

```sh
# Pinned formatting/lint and evaluation with isolated test settings; macOS OK.
./scripts/check.sh

# Also evaluate the real host settings (requires disk and SSH keys to be set).
./scripts/check.sh --deployment

# Requires a matching Linux builder; produces result-deploy, never activates.
./scripts/build.sh
```

See [engineering standards](docs/CONTRIBUTING.md) and the
[deployment acceptance checklist](docs/DEPLOYMENT.md). Future coding sessions
must follow [AGENTS.md](AGENTS.md). CI runs checks and a Linux fixture build;
that is not proof the real host is deployment-ready or boot-tested.

## Persistence policy

`modules/persistence.nix` is the initial allowlist:

| Persistent path | Purpose |
| --- | --- |
| `/etc/nixos` | Configuration checkout, backed by `/persist/etc/nixos` |
| `/var/lib/nixos` | Stable system UID/GID allocations and NixOS state |
| `/var/lib/systemd` | Random seed and persistent timer state |
| `/var/lib/dhcpcd` (when enabled) | Stable DHCP identity and leases |
| `/var/log` | Diagnostics; journald capped at 256 MiB |
| `/etc/machine-id` | Stable machine identity |
| Configured SSH host keys and public keys | Stable SSH identity and sops-nix decryption |

Everything else on root, including `/home`, `/root`, `/tmp`, and unlisted
`/var/lib` state, disappears at reboot. Declarative configuration is recreated
from `/nix/store`. Keep working files in the persisted checkout or deliberately
add a narrow persistence entry; do not broadly persist `/etc` or `/var`.

The root tmpfs can use up to **25% of RAM** (allocated on demand). Large
transient writes can fill it or exhaust memory; put large build/download work
on persistent storage and size the target's RAM accordingly. `/nix`, `/persist`
and `/boot` are not wiped, and impermanence is not a secure-erasure guarantee.
Back up `/persist` and review its contents as you add features. Home Assistant
will need its state directory explicitly persisted when enabled.

**Existing installation:** this is a new disk layout, not an in-place migration.
Do not simply switch an existing ext4-root host to this configuration. Back up
its data, configuration and SSH host keys, then reinstall (or plan a separate,
manual filesystem migration). Running disko destroys the old disk contents.

## Initial installation

Boot the target using a NixOS installer with UEFI and network connectivity.
Become root (`sudo -i`), clone this repository to `/tmp/arbour-haus`, and edit
its target settings as above. If Git is unavailable, use `nix-shell -p git`.
Run all commands below from `/tmp/arbour-haus`.

**The disko script irreversibly erases the configured disk. Check the disk
identity and back up existing data before running it. Do not run it on the
development machine or as part of routine updates.**

```sh
# Check and fully build the real system before doing anything destructive.
./scripts/build.sh

# Build the pinned disko script, then explicitly partition/format/mount /mnt.
nix-build -A nixosConfigurations.arbour-haus.config.system.build.diskoScript \
  -o result-disko
./result-disko

# Write directly into persistent storage: /mnt/etc is currently ephemeral.
# Impermanence exposes this checkout at /etc/nixos after boot.
mkdir -p /mnt/persist/etc/nixos
cp -a /tmp/arbour-haus/. /mnt/persist/etc/nixos/

# Install exactly the closure that passed the build gate above.
nixos-install --system "$(readlink /tmp/arbour-haus/result-deploy)" --no-root-passwd
reboot
```

After reboot, connect using `ssh admin@<host-ip>`. There is no password-based
fallback; verify that the configured public key is yours before installation.
The generic layout is unencrypted: physical access is outside its threat model.

Before relying on the host, verify persistence over a real reboot:

```sh
# Record these, reboot, and confirm they remain unchanged.
cat /etc/machine-id
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
sudo touch /persist/persistence-check
sudo touch /root/ephemeral-check
sudo reboot
# After reconnecting:
sudo test -e /persist/persistence-check
sudo test ! -e /root/ephemeral-check
findmnt /
findmnt /nix
findmnt /persist
sudo test -f /etc/nixos/configuration.nix
sudo rm /persist/persistence-check
```

## Subsequent deployments

On the host, update the checkout at `/etc/nixos` (or copy a reviewed revision
there), then build a candidate:

```sh
./scripts/build.sh
```

Follow [deployment acceptance and recovery](docs/DEPLOYMENT.md) to review and
activate that exact `result-deploy` closure. No activation is automated. The
legacy `configuration.nix` bridge remains available for `nixos-rebuild`, using
the installed pinned `nix.nixPath`; no flake argument is used. Keep console
access available and a known-good generation until reboot checks pass.

## Dependency updates

```sh
nix-shell
npins show
npins update                 # nixpkgs stays within the pinned stable release
./scripts/check.sh
# Build with real settings on Linux before deploying: ./scripts/build.sh
# Review and commit npins/sources.json with the configuration changes.
```

The auxiliary projects track pinned commits on their upstream branches; updates
must be tested against stable nixpkgs. To migrate NixOS releases explicitly use
`npins add --name nixpkgs channel nixos-<release>`. Do **not** automatically bump
`system.stateVersion` when updating nixpkgs. Keep the generated
`npins/default.nix` committed; do not hand-edit it.

See [secrets/README.md](secrets/README.md) before adding any secrets.
