{
  description = "A flake for building vscodium with selected extensions";

  inputs.nixpkgs.url = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";
  inputs.rust-overlay.inputs.flake-utils.follows = "flake-utils";
  inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, rust-overlay }: flake-utils.lib.simpleFlake {
    inherit self nixpkgs;
    name = "vsc";
    preOverlays = [ rust-overlay.overlay ];
    systems = [ "aarch64-darwin" ];
    config = {
      allowUnsupportedSystem = true;
    };
    overlay = final: prev: {
      vsc = with final; rec {
        env = [ rust-bin.stable.latest.rust ];

        wrapper = vscode-with-extensions.override {
          vscode = vscodium;
          vscodeExtensions = with vscode-extensions; [
            matklad.rust-analyzer
          ];
        };

        codium = stdenv.mkDerivation {
          pname = "codium";
          version = "1.0";
          phases = ["installPhase"];
          installPhase = ''
            mkdir -p $out/bin;
            makeWrapper ${wrapper}/bin/codium $out/bin/codium --prefix PATH : ${lib.makeBinPath env}
          '';
          buildInputs = [ makeWrapper ];
        };

        defaultPackage = codium;
      };

      darwinConfigurations = {
        myVSC = prev.vsc // {
          codium = prev.vsc.codium.overrideAttrs (oldAttrs: rec {
            preConfigure = ''
              substituteInPlace src/main.native -e 's/N.X11SetWindowIcon/N.XSetWindowIcon/' || echo "Patch failed!"
            '';
            postInstall = ''
              mkdir -p $out/vscodium_icon/
              cp ${self}/icon.icns $out/vscodium_icon/VSCodium.icns
              find dist -type f -exec sed -i 's/VSCodium/VSCodium Custom Name/g' {} \\;
              cp -nR dist $out/VSCodium.app
            '';
          });
        };
      };
    };
  };
}
