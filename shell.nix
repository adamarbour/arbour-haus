let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    npins
    sops
    age
    ssh-to-age
    nixfmt
    shellcheck
  ];
}
