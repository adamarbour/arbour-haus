{
  description = "arbour-haus: a single impermanent NixOS host";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      # Only the NixOS module is needed, not upstream's development inputs.
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      mkHost =
        hostSettings:
        lib.nixosSystem {
          specialArgs = { inherit inputs hostSettings; };
          modules = [ ./hosts/arbour-haus/configuration.nix ];
        };
      hosts = {
        arbour-haus = mkHost (import ./host-settings.nix);
      };
      # Lazily evaluated fixtures never enter the production module graph.
      fixture = mkHost (import ./tests/host-settings.nix);
      evaluation = import ./tests/eval.nix {
        inherit mkHost;
        hostNames = builtins.attrNames hosts;
      };
    in
    {
      nixosConfigurations = hosts;
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShellNoCC {
          packages = with nixpkgs.legacyPackages.${system}; [
            sops
            age
            ssh-to-age
            nixfmt
            shellcheck
          ];
        };
      });
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          evaluation = pkgs.writeText "arbour-haus-evaluation.json" (builtins.toJSON evaluation);
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          fixture-system = fixture.config.system.build.toplevel;
          fixture-disko = fixture.config.system.build.diskoScript;
        }
      );
    };
}
