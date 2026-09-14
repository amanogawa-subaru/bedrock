{
  description = "Bedrock NixOS platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = import ./default.nix;
    homeModules.default = import ./home;
  };
}

