{ config, lib, pkgs, ... }:

{
  environment.systemPackages =
    [ pkgs.ack
      pkgs.autoconf
      pkgs.automake
      pkgs.cmake
      pkgs.dtach
      pkgs.fasd
      pkgs.fontforge
      pkgs.fortune
      pkgs.figlet
      pkgs.ffmpeg
      pkgs.fzf
      pkgs.gdbm
      pkgs.git
      pkgs.git-crypt
      pkgs.gnupg
      pkgs.go
      pkgs.irssi
      pkgs.jq
      pkgs.lame
      pkgs.luajit
      pkgs.mosh
      pkgs.neovim
      pkgs.perl
      pkgs.pinentry
      pkgs.python27Packages.neovim
      pkgs.python27Packages.powerline
      pkgs.python36Packages.neovim
      pkgs.python27Packages.pylint
      pkgs.python36Packages.pylint
      pkgs.reattach-to-user-namespace
      pkgs.silver-searcher
      pkgs.terminal-notifier
      pkgs.tmux
      pkgs.unrar
      pkgs.vim-vint
      pkgs.zsh

      pkgs.nix
      pkgs.nix-repl ];

  programs.zsh.enable = true;

  services.activate-system.enable = true;
}