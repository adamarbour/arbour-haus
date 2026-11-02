# Check/build harness and agent standards

The harness is the repository's plain flake, isolated tests, and two shell
entry points. It is not a deployment framework. Agent rules live in
[`AGENTS.md`](../AGENTS.md); engineering standards live in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Contracts

| Command | What it establishes | What it does not do |
| --- | --- | --- |
| `./scripts/check.sh` | Pinned nixfmt and shellcheck, shell syntax, Git whitespace checks, isolated evaluation | Build a Linux system or validate real target settings |
| `./scripts/check.sh --deployment` | Above, plus real system and disko derivation evaluation | Realize either derivation or test bootability |
| `./scripts/build.sh` | Above, plus realize the real system and create `result-deploy` | Format disks, install, activate, or reboot |

The scripts resolve their own checkout directory and use `path:<checkout>`.
New files are visible without staging. They refuse lock updates; do not edit
or pull while a check/build is running. The development shell supplies pinned
tools. Do not set `ARBOUR_CHECK_TOOLS=1` yourself to bypass that shell.
`git diff --check` requires a Git working tree; these scripts are not currently
an archive-only build interface. A target receiving a prebuilt closure does
not need Git or these scripts.

`tests/eval.nix` uses isolated, deliberately unusable disk/key settings.
`checks.x86_64-linux.fixture-system` and `fixture-disko` are CI artifacts, not
installation candidates. Do not weaken fixture assertions or substitute a
fixture for the operator's real settings. The Linux package check below reads
the pinned Ghostty terminal entry with ncurses; evaluation separately verifies
that the host installs it and links the system terminfo database:

```sh
nix build --no-update-lock-file --no-link \
  "path:$PWD#checks.x86_64-linux.ghostty-terminfo"
```

This package check does not require booting or building the complete host.

`build.sh` removes an old `result-deploy` symlink before starting and removes
it again on failure. It refuses to overwrite a regular file/directory at that
path. Success checks for `bin/switch-to-configuration` in the realized output.
Keep this GC root until the candidate is transferred and rooted on the target.
An unrelated `result` link is not evidence of a successful host build.

## Builder preflight

The default host is `x86_64-linux`. macOS can evaluate it, but realizing it
requires an available Linux builder advertising that architecture. A remote
builder or Determinate external builder is fine; do not change the host
architecture merely to match the workstation.

```sh
nix --version
nix config show | grep -E '^(system|builders|external-builders|extra-platforms|experimental-features) ='
./scripts/check.sh --deployment
./scripts/build.sh
```

Enable `nix-command flakes` if needed. Inspect the configured builder mechanism:
`builders = @/etc/nix/machines` with no machines file does not rule out an
`external-builders` configuration. Configuration alone is not proof of a
successful build; the actual system build is the gate. Never print credentials
or private builder keys while diagnosing access. Keep builder credentials
outside this repository.

## Agent execution and reporting

- Read the required repository docs and inspect `git status` before edits.
  Preserve user changes; do not stage, commit, push, or update pins unasked.
- Document behavior and update regression coverage when behavior changes.
  Documentation-only edits still run the default check; no runtime claim follows.
- Builds are not deployment authorization. Disk operations, install, activation,
  reboot, and identity changes require explicit operator permission.
- Keep complete build logs outside the checkout, without secret contents.
  Wait for completion and inspect the exit status; a derivation path or a
  partially populated store is not success.
- Report formatting/lint, evaluation, fixture build, real build, activation,
  and reboot acceptance separately. Include exact commands, candidate closure
  when available, and unresolved operator checks. Inspect the final diff.
- Diagnose failed dependencies rather than disabling safety checks, changing
  disk settings, or updating dependencies as an unrelated workaround.

## Build and installation status

The build attempted after configuring the x86 Linux builder passed the check
and real-host evaluation gates but failed building `initrd-linux-6.18.60`.
The initrd builder reported a missing
`ncurses-6.6/share/terminfo/l/linux` store path. No `result-deploy` was produced;
nothing was installed or activated. The session log was
`/tmp/arbour-haus-build.log` (temporary, not a durable record).

The operator subsequently reported a successful initial installation, working
SSH access, and Tailscale setup. The successful build's closure/platform and
the cause of the earlier local failure have not been recorded here; do not
infer that a new build in this checkout will succeed. Full reboot/persistence
acceptance is still unrecorded. Every new candidate must pass the real-settings
build gate; if the initrd failure recurs, investigate its full log and dependency
contents rather than applying an unreviewed workaround.

The local build attempt for the Ghostty terminfo change reproduced the same
initrd failure (`/tmp/arbour-haus-ghostty-build.log`); no new `result-deploy`
was produced. Formatting, real-host evaluation, and the Linux Ghostty terminfo
package check passed. The Ghostty fix has not been activated or verified in a
live SSH session by the agent.
