{
  hostSettings ? import ./host-settings.nix,
}:
let
  sources = import ./npins;
  lib = import "${sources.nixpkgs}/lib";
  # Call the upstream output function as plain Nix: no flake evaluation,
  # registry, lock file, or experimental features are involved. Reuse our
  # pinned nixpkgs lib rather than fetching flake-parts' own nixpkgs-lib input.
  flakeParts = (import "${sources.flake-parts}/flake.nix").outputs {
    self = { };
    nixpkgs-lib = { inherit lib; };
  };
in
flakeParts.lib.mkFlake
  {
    inputs = { };
    self = {
      outPath = ./.;
    };
    moduleLocation = ./default.nix;
    specialArgs = { inherit sources hostSettings; };
  }
  {
    systems = [ ];
    imports = [ flakeParts.flakeModules.modules ] ++ (import ./lib/import-tree.nix ./modules);
  }
