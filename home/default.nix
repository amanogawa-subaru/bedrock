{ pkgs, firefox-addons, ... }:

{
  imports = [
    ./xdg.nix
  ];

  # Firefox enabled as fallback browser
  programs.firefox = {
    enable = true;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "extensions.autoDisableScopes" = 0;
      };

      extensions = {
        force = true;

	packages = 
	  with firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
            firefox-color
	    ublock-origin
	    bitwarden
	  ];
      };
    };
  };

  # Librewolf as default browser
  programs.librewolf = {
    enable = true;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "extensions.autoDisableScopes" = 0;
      };

      extensions = {
        force = true;

	packages = 
	  with firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
            firefox-color
	    bitwarden
	  ];
      };
    };
  };

  # Enable neovim
  programs.neovim = {
    enable = true;

    initLua = builtins.readFile ./nvim/init.lua;
  };
}
