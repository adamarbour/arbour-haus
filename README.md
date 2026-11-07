# arbour-haus

A single-host NixOS flake for an impermanent, SSH-administered server.
Home Assistant is **not enabled yet**. [Iteration 2](docs/ITERATION-2.md) plans
Home Assistant, Mosquitto, Zigbee2MQTT, and Z-Wave JS for two PoE network radios;
the SONOFF hardware inventory and provisional addresses are recorded there.
Home Assistant will be accessible over both LAN and Tailscale. The plan includes
an [operator worksheet](docs/ITERATION-2.md#operator-fill-in-worksheet) for radio
firmware/transport settings; implementation awaits those and provisioning details.
Matter and Thread are deferred.

- Stable **NixOS 26.05**, with dependencies pinned in `flake.lock`.
- Ordinary NixOS modules and explicit imports; no flake-parts or Home Manager.
- **disko:** one UEFI/GPT disk, 512 MiB EFI partition, Btrfs `/nix` and
  `/persist` subvolumes. No swap or disk encryption.
- **Impermanence:** tmpfs `/`, with an explicit persistence allowlist.
- **Access:** key-only OpenSSH as `admin`, over the LAN or Tailscale.
- **Updates:** PRs reviewed/approved and merged only by Adam Arbour; `main`
  is the production boundary for planned automatic rebuild/deployment.
  Current activation remains manual until deployment automation is implemented.
- **sops-nix:** ready for encrypted secrets; none are required for first boot.

## Layout

```text
flake.nix / flake.lock       # dependencies, sole host, tools and isolated checks
host-settings.nix           # target architecture, disk and public SSH keys
hosts/arbour-haus/           # composition and hardware settings
modules/                    # explicit, ordinary NixOS modules
secrets/                    # SOPS-encrypted payloads and instructions
tests/                      # isolated fixtures; never installation entry points
scripts/check.sh            # pinned formatting, shell lint and evaluation
scripts/build.sh            # real-host build -> result-deploy; never activates
docs/                       # harness standards, installation and recovery
```

## Pull requests and deployment

**Treat merging into `main` as a production action: it is intended to trigger
rebuild and deployment after checks pass.** All changes, including docs, go
through feature branches and PRs. **Adam Arbour is the sole reviewer and
approver, and only Adam may merge.** Humans and AI agents must not push directly
to `main`, enable auto-merge, or bypass review.

Read the [GitHub deployment policy](docs/GITHUB_DEPLOYMENT.md) for the workflow,
required GitHub controls, and agent responsibilities. Today Actions only
validates/builds fixtures; automatic production deployment and enforcement
are not enabled by this documentation change. GitHub deployment is currently
paused in favor of iteration 2. When asked to revisit it, resume from the
[saved deployment checkpoint](docs/GITHUB_DEPLOYMENT.md#paused-work-resume-github-deployment-here).

## Configure the target

Review `host-settings.nix` even if its disk and key are already populated:

1. Confirm `system` and **UEFI** support. The baseline is a generic x86_64 PC/VM,
   not a Raspberry Pi or BIOS-only machine.
2. Inspect `lsblk` and `/dev/disk/by-id` on the target and confirm the exact disk.
3. Confirm `adminAuthorizedKeys` contains your actual public key.
4. Inspect `nixos-generate-config --show-hardware-config` on the target and
   incorporate relevant hardware settings in `hosts/arbour-haus/hardware.nix`.
   Do not copy its filesystem entries: disko owns those.

Missing disk/key settings intentionally fail build assertions. DHCP, UTC,
key-only SSH, disabled root login, and passwordless sudo for `admin` are the
baseline. The admin key grants root-equivalent access. Reserve a LAN address
in DHCP if useful; the hostname alone does not guarantee LAN DNS resolution.
Do not expose SSH through router port forwarding. The host permits TCP 22 on
its interfaces; the router and tailnet policy determine external reachability.

## Check and build

Use Nix with `nix-command` and `flakes` enabled. On a workstation where needed,
set `NIX_CONFIG='experimental-features = nix-command flakes'` for the session.
The installed host enables these features declaratively.

```sh
./scripts/check.sh                 # pinned formatter/lint + isolated eval; macOS OK
./scripts/check.sh --deployment    # additionally evaluate the real host settings
./scripts/build.sh                 # matching Linux builder; result-deploy, no activation
nix develop                       # pinned nixfmt, shellcheck, sops, age, ssh-to-age
```

Scripts use a local path flake so new files are visible before staging. Normal
Git-flake commands such as `nix flake check` see only Git-tracked files: add new
files before using those commands. Do not edit the checkout during a build.
Checks and CI fixture builds are not proof that the target boots.

See [engineering standards](docs/CONTRIBUTING.md),
[harness contracts and builder troubleshooting](docs/HARNESS.md),
[deployment acceptance](docs/DEPLOYMENT.md), and [agent instructions](AGENTS.md).

## Persistence policy

| Persistent path | Purpose |
| --- | --- |
| `/etc/nixos` | Root-owned Git checkout, backed by `/persist/etc/nixos` |
| `/var/lib/nixos` | Stable UID/GID allocation and system state |
| `/var/lib/systemd` | Random seed and persistent timer state |
| `/var/lib/dhcpcd` (when enabled) | DHCP identity and leases; dhcpcd:dhcpcd, 0750 |
| `/var/lib/tailscale` | Node identity and preferences; root:root, 0700 |
| `/var/log` | Diagnostics; journald capped at 256 MiB |
| `/etc/machine-id` | Stable machine identity |
| Configured SSH host keys and public keys | Stable SSH identity and sops decryption |

The checkout is root:root, 0755. System state otherwise retains upstream
ownership/modes; SSH private keys must remain root-only. Homes (`/home`,
`/root`), `/tmp`, and all unlisted state disappear at reboot. Do not broadly
persist `/etc`, `/var`, or `/home`. Future services must declare their state,
ownership, backup policy, and runtime secrets alongside their module.

Root tmpfs can use **25% of RAM**, allocated on demand. Put large downloads and
build work on persistent storage. Impermanence is not secure erasure or a
backup: `/nix`, `/persist`, and `/boot` survive. Back up `/persist` securely,
particularly host keys, Tailscale identity, encrypted secrets, and the checkout;
keep reviewed configuration in an off-host Git remote. Treat identity backups
as private credentials. See [recovery](docs/DEPLOYMENT.md#recovery).

## Initial installation

Follow the [initial deployment procedure](docs/DEPLOYMENT.md#initial-deployment-fresh-installation-only)
on the target's UEFI NixOS installer. It covers reviewing hardware/disk/key
settings, successfully building the real candidate, explicitly authorized disk
erasure, installing that exact closure, and reboot acceptance. **Disk formatting
irreversibly destroys existing contents; never use it for an ordinary update.**

The operator has reported a successful initial installation, SSH access, and
Tailscale setup. Full reboot/persistence acceptance has not been recorded here.
See the [build history](docs/HARNESS.md#build-and-installation-status) for an
earlier local build failure. Every new candidate must still pass the build gate.

Connect afterward with `ssh admin@<lan-ip>`. There is no password fallback.
Verify the host fingerprint through a trusted channel. This unencrypted layout
assumes physical access is outside the threat model.

## Tailscale enrollment

While connected over LAN SSH, enroll interactively:

```sh
sudo tailscale up --ssh=false --accept-routes=false --accept-dns=false
sudo tailscale status
```

Approve the node if required by your tailnet. Configure tailnet grants/ACLs to
allow only intended administrators to reach this node on TCP 22; enrollment
alone is not an access policy. Review device key expiry for an unattended
server. Test `ssh admin@<tailscale-ip>` from an authorized tailnet client.

Tailscale SSH is disabled: both paths use the same OpenSSH key authentication.
There is no exit node, subnet routing, Taildrop, or blanket trusted interface.
UDP 41641 is opened for tunnel transport. The persisted root-only state keeps
enrollment across reboots; no auth key or SOPS secret is needed. Loss of this
state requires re-enrollment; do not run restored copies of an identity on two
machines. LAN SSH remains the independent recovery path.

## Ghostty SSH terminals

The host installs `ghostty.terminfo` from pinned nixpkgs, not the graphical
terminal application. This lets remote programs recognize Ghostty's forwarded
`TERM=xterm-ghostty` over both LAN and Tailscale OpenSSH. It adds no writable
state, secrets, ports, or persistence requirements. Do not install terminfo
only in an ephemeral home or permanently override `TERM` to hide the problem.

After rebuilding and activating via the [manual update procedure](docs/DEPLOYMENT.md#manual-redeployment-without-git-on-the-target),
open a fresh Ghostty SSH session and verify on the host:

```sh
printf '%s\n' "$TERM"  # xterm-ghostty
infocmp xterm-ghostty >/dev/null
tput colors
sudo infocmp xterm-ghostty >/dev/null
```

Also check `clear` and `vim` interactively. If the old generation prevents
comfortable use before redeploying, connect once from Ghostty with
`TERM=xterm-256color ssh admin@<host>` as a temporary compatibility fallback.
Keep Ghostty's normal TERM for verification after activation. No Tailscale
re-enrollment or reboot is needed for the terminfo change.

## Git-based updates

On the host, update the root-owned checkout to a reviewed revision:

```sh
cd /etc/nixos
sudo git status --short             # stop and reconcile local changes first
sudo git pull --ff-only
sudo ./scripts/build.sh
```

Use a public/readable Git remote or a separately provisioned read-only runtime
credential for private repositories. No Git private key is installed by this
configuration; homes and their credentials are ephemeral. Never put a Git
credential in the flake or its URLs.

Review and activate the exact candidate following
[deployment acceptance and recovery](docs/DEPLOYMENT.md). Nothing automatically
pulls Git or activates updates. Keep a working SSH session and known-good
system generation until reboot acceptance passes.

## Manual updates without Git on the target

Use the [prebuilt-closure redeployment procedure](docs/DEPLOYMENT.md#manual-redeployment-without-git-on-the-target):
build with real settings on the workstation/Linux builder, transfer the complete
closure over verified SSH, root it on the target, and explicitly activate that
exact candidate. The target needs neither Git nor a rebuild. Do not rerun disko
or installation. The persisted source checkout remains unchanged; retain source
provenance separately and complete the same rollback/reboot acceptance checks.

## Dependency updates

On the development checkout:

```sh
nix flake update                  # or: nix flake update nixpkgs
./scripts/check.sh --deployment
# Review and commit flake.lock alongside related configuration changes.
# Build real settings on Linux before activation: ./scripts/build.sh
```

Nixpkgs stays on `nixos-26.05` until an explicit release migration; other inputs
track locked upstream commits. All flake inputs that need nixpkgs follow the
same stable pin. Impermanence is a source-only input to avoid unrelated
upstream development dependencies. Do not bump `system.stateVersion` with
routine updates. This migration preserves the existing dependency revisions
and disk layout; it replaces npins and the legacy rebuild bridge.

See [secrets/README.md](secrets/README.md) before adding secrets.
