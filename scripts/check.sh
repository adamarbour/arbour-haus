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
  # mode is restricted to a fixed string above, not interpolated user code.
  exec nix-shell "$root/shell.nix" --run "ARBOUR_CHECK_TOOLS=1 bash scripts/check.sh $mode"
fi

# Catch lock formats unsupported by stable nixpkgs' npins before an update.
npins show >/dev/null

while IFS= read -r -d '' file; do
  nixfmt --check "$file"
done < <(find . -type f -name '*.nix' \
  -not -path './.git/*' -not -path './npins/*' -not -path './.direnv/*' -print0)
shellcheck scripts/*.sh
bash -n scripts/check.sh scripts/build.sh
git diff --check
nix-instantiate --eval --strict tests/eval.nix
nix-instantiate --eval --strict tests/legacy.nix

if [[ "$mode" == --deployment ]]; then
  nix-instantiate --eval --strict \
    -A nixosConfigurations.arbour-haus.config.system.build.toplevel.drvPath
  nix-instantiate --eval --strict \
    -A nixosConfigurations.arbour-haus.config.system.build.diskoScript.drvPath
fi

echo "Checks passed${mode:+ (including real host evaluation)}. No system was built or activated."
