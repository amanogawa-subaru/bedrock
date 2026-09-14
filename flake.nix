{
  description = "Bedrock NixOS platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, firefox-addons, ... }: {
    nixosModules.default = import ./default.nix;
    
    homeModules.default = {
      _module.args = {
        inherit firefox-addons;
      };

      imports = [
        ./home
      ];
    };
  };
}

