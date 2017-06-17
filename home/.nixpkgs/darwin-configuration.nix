{ config, lib, pkgs, ... }:

{
  environment.systemPackages =
    [ pkgs.autoconf
      pkgs.automake
      pkgs.figlet
      pkgs.fzf
      pkgs.git
      pkgs.git-crypt
      pkgs.gnupg
      pkgs.go
      pkgs.irssi
      pkgs.jq
      pkgs.lame
      pkgs.mosh
      pkgs.nix
      pkgs.perl
      pkgs.tmux
      pkgs.zsh

      pkgs.nix
      pkgs.nix-repl ];

  programs.zsh.enable = true;

  services.activate-system.enable = true;
}
