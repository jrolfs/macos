{
  description = "Jamie's machines — cross-host nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim config — separate repo, consumed as a source tree.
    neovim-config = {
      url = "github:jrolfs/neovim";
      flake = false;
    };

    # Theme / plugin source trees that land in $HOME via home-manager
    # source = "${inputs.X}". All flake = false.
    kitty-gruvbox-material = {
      url = "github:jrolfs/gruvbox-material-kitty";
      flake = false;
    };
    tridactyl-gruvbox-material = {
      url = "github:jrolfs/gruvbox-material-tridactyl";
      flake = false;
    };
    spicetify-gruvbox-material = {
      url = "github:whiterqbbit/spicetify-gruvbox-material";
      flake = false;
    };
    zinit = {
      url = "github:zdharma-continuum/zinit";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      userName = "jamie";

      mkDarwin = hostname: system: nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs hostname userName; };
        modules = [
          ./modules/darwin
          ./hosts/${hostname}
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs hostname userName; };
            home-manager.users.${userName} = import ./modules/home;
            home-manager.sharedModules = [ ./modules/home/darwin.nix ];
          }
        ];
      };

      mkNixos = hostname: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname userName; };
        modules = [
          ./modules/nixos
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs hostname userName; };
            home-manager.users.${userName} = import ./modules/home;
            home-manager.sharedModules = [ ./modules/home/linux.nix ];
          }
        ];
      };
    in
    {
      darwinConfigurations.ala = mkDarwin "ala" "aarch64-darwin";
      # darwinConfigurations.newt = mkDarwin "newt" "aarch64-darwin";  # phase 3

      nixosConfigurations.irulan = mkNixos "irulan" "x86_64-linux";  # phase 2
    };
}
