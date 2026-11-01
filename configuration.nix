# Compatibility entry point for the non-flake nixos-rebuild command.
{ ... }:
{
  imports = [ (import ./. { }).modules.nixos.host ];
}
