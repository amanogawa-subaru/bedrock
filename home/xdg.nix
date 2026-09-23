{ pkgs, ... }:

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
  # XDG configuration
  xdg = {
    enable = true;

    # Create user directories
    userDirs = {
      enable = true;
      createDirectories = true;
    };

    configFile = {
      "foot/foot.ini".source = ./dots/foot/foot.ini;
    };

    mimeApps = {
      enable = true;

      defaultApplications = {
        "inode/directory" = [ "nemo.desktop" ];
        "application/x-gnome-saved-search" = [ "nemo.desktop" ];

        "text/plain" = [ "nvim.desktop" ];
	"text/x-lua" = [ "nvim.desktop" ];
        "text/x-qml" = [ "nvim.desktop" ];
	"text/csv" = [ "nvim.desktop" ];

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

    # Set default applications
    desktopEntries = {
      nemo = {
        name = "Nemo";
	exec = "${pkgs.nemo-with-extensions}/bin/nemo";
      };

      nvim = {
        name = "Neovim";
	genericName = "Text Editor";
	exec = "foot nvim %F";
	icon = "nvim";
	terminal = false;
	type = "Application";

	mimeType = [
          "text/plain"
	  "text/x-lua"
	  "text/x-qml"
	  "text/csv"
	];
      };
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
    exec = "foot";
  };
}
