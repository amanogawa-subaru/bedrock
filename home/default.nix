{ pkgs, firefox-addons, ... }:

let
  comic-thumbnailer = pkgs.writeShellApplication {
    name = "comic-thumbnailer";

    runtimeInputs = with pkgs; [
      _7zz
      imagemagick
    ];

    text = builtins.readFile ./scripts/comic-thumbnailer;
  };
in

{
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

  # XDG configuration
  xdg = {
    enable = true;

    # Create user directories
    userDirs = {
      enable = true;
      createDirectories = true;
    };

    mimeApps = {
      enable = true;

      defaultApplications = {
        "inode/directory" = [ "nemo.desktop" ];
        "application/x-gnome-saved-search" = [ "nemo.desktop" ];

        "text/plain" = [ "geany.desktop" ];
        "text/x-lua" = [ "geany.desktop" ];
        "text/x-qml" = [ "geany.desktop" ];

        "image/jpeg" = [ "imv.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/webp" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "image/bmp" = [ "imv.desktop" ];
        "image/tiff" = [ "imv.desktop" ];

        "audio/flac" = [ "org.gnome.Lollypop.desktop" ];
        "audio/mpeg" = [ "org.gnome.Lollypop.desktop" ];

        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-msvideo" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];

        "application/pdf" = [ "onlyoffice-desktopeditors.desktop" ];

        "x-scheme-handler/http" = [ "librewolf.desktop" ];
        "x-scheme-handler/https" = [ "librewolf.desktop" ];
        "text/html" = [ "librewolf.desktop" ];
        "application/xhtml+xml" = [ "librewolf.desktop" ];

        "application/vnd.comicbook+zip" = [ "mcomix.desktop" ];
      };	
    };

    # Set nemo as default file browser
    desktopEntries.nemo = {
      name = "Nemo";
      exec = "${pkgs.nemo-with-extensions}/bin/nemo";
    };  
    
    # Comic thumbnailer
    dataFile."thumbnailers/comic.thumbnailer".text = ''
      [Thumbnailer Entry]
      Exec=${comic-thumbnailer}/bin/comic-thumbnailer %i %s %o
      MimeType=application/vnd.comicbook+zip;
    '';

  };
  
  # Set default terminal for Nemo
  dconf.settings."org/cinnamon/desktop/applications/terminal" = {
    exec = "kitty";
  };
}
