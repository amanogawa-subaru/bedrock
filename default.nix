{ lib, ... }:

let
  settings = import ./settings.nix;
  username = settings.username;
in
{
  _module.args = {
    inherit username settings;
  };

  imports = [
    ./modules/system.nix
    ./modules/fonts.nix
    ./modules/mount.nix
    ./modules/user-packages.nix
  ]
  ++ lib.optional settings.nvidia ./modules/nvidia.nix
  ++ lib.optional settings.nvidiaPrime ./modules/nvidia-prime.nix;
}
