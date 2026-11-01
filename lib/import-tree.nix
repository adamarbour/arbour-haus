# Every .nix file under modules/ is a flake-parts module, never a bare
# NixOS module. Sorting via attrNames makes discovery deterministic.
dir:
let
  entries = builtins.readDir dir;
in
builtins.concatMap (
  name:
  let
    path = dir + "/${name}";
    type = entries.${name};
  in
  if type == "directory" then
    import ./import-tree.nix path
  else if type == "regular" && builtins.match ".*\\.nix" name != null then
    [ path ]
  else
    [ ]
) (builtins.attrNames entries)
