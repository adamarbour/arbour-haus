#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
if [[ $# -ne 0 ]]; then
  echo "Usage: $0 (uses real host-settings.nix; never activates)" >&2
  exit 2
fi

# Never let a previous successful build masquerade as this run's candidate.
# Only remove our output symlink, never a real file/directory or a store path.
if [[ -L result-deploy ]]; then
  rm -- result-deploy
elif [[ -e result-deploy ]]; then
  echo "Refusing to replace non-symlink result-deploy" >&2
  exit 1
fi
trap 'if [[ -L result-deploy ]]; then rm -- result-deploy; fi; echo "Build failed: no new deployment candidate was produced." >&2' ERR

bash scripts/check.sh --deployment
# Let nix-build register the output symlink as a GC root until activation.
system=$(nix-build "$root" --out-link result-deploy \
  -A nixosConfigurations.arbour-haus.config.system.build.toplevel)
test -x "$system/bin/switch-to-configuration"
printf 'Deployment candidate: %s/result-deploy -> %s\n' "$root" "$system"
echo "Built with real settings. Not activated or boot-tested."
