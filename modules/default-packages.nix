# This module is intended for default packages to be used accross profiles
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # File management
    nemo-with-extensions
    ffmpegthumbnailer
    bulky
    webp-pixbuf-loader
    unzip
    file

    # Media
    imv
    lollypop
    mpv
    mcomix

    # Editing
    onlyoffice-desktopeditors

    # CLI
    fastfetch
    btop
    
    # Tools
    git
  ];
}
