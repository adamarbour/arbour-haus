#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
mode=${1:-}
if [[ $# -gt 1 || ( -n "$mode" && "$mode" != --deployment ) ]]; then
  echo "Usage: $0 [--deployment]" >&2
  exit 2
fi

if [[ ${ARBOUR_CHECK_TOOLS:-} != 1 ]]; then
  # Always use the pinned tools, even if other versions exist on the host.
  exec nix develop --no-update-lock-file "path:$root" --command \
    env ARBOUR_CHECK_TOOLS=1 bash scripts/check.sh "$mode"
fi

# A local path flake includes new files without staging the user's work.
flake="path:$root"
system=$(nix eval --impure --raw --expr builtins.currentSystem)

while IFS= read -r -d '' file; do
  nixfmt --check "$file"
done < <(find . -type f -name '*.nix' \
  -not -path './.git/*' -not -path './.direnv/*' -print0)
shellcheck scripts/*.sh
bash -n scripts/check.sh scripts/build.sh
git diff --check
nix eval --no-update-lock-file --raw "$flake#checks.$system.evaluation.drvPath"
printf '\n'

if [[ "$mode" == --deployment ]]; then
  nix eval --no-update-lock-file --raw \
    "$flake#nixosConfigurations.arbour-haus.config.system.build.toplevel.drvPath"
  printf '\n'
  nix eval --no-update-lock-file --raw \
    "$flake#nixosConfigurations.arbour-haus.config.system.build.diskoScript.drvPath"
  printf '\n'
fi

echo "Checks passed${mode:+ (including real host evaluation)}. No system was built or activated."
