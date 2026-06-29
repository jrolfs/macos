# Pin a single package to an older nixpkgs revision when the current
# revision's build isn't in the binary cache yet (common on aarch64-darwin,
# where Hydra's Darwin builders lag the channel). Returns the pinned package
# wrapped in an evaluation warning that prints, on every rebuild:
#
#   - the pinned version and the nixpkgs sha it comes from
#   - the current version and the nixpkgs sha the system is building
#   - whether that current build is in the binary cache yet, so we know
#     when the pin is safe to remove (✅) or still needed (❌)
#
# Usage from an overlay (`self: super:`):
#
#   let pin = import ./pin.nix super;
#   in {
#     mise = pin {
#       name   = "mise";
#       rev    = "baf9fac791ea8173567a01ac2b21c96806c63b05";
#       sha256 = "02k7092jj3qql9hxl7zawxi89917kbyjk6a17mf118hicq1cp84y";
#     };
#   }

pkgs:

let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  short = lib.substring 0 12;

  # Is a store path on cache.nixos.org? There's no pure builtin for this, and
  # `builtins.fetchurl` on a missing narinfo throws an error `tryEval` can't
  # trap, so we shell out via import-from-derivation. Bucketed by day with
  # `currentTime` so a once-missing build is re-checked daily rather than
  # memoised as missing forever. Relies on `sandbox = false` (the darwin
  # default) for build-time network; on any HTTP/network failure the probe
  # writes "unknown" rather than failing, so it can't break a rebuild. (The
  # IFD read is deliberately *not* wrapped in tryEval: Nix forbids IFD inside
  # tryEval and raises an uncatchable "path did not exist" error if you try.)
  cacheStatus = drv:
    let
      # `drv.outPath` carries string context; without discarding it, deriving
      # the hash and interpolating it into the probe would make `drv` a build
      # dependency of the probe — i.e. it would *build the very package we
      # pinned away from* (and fail the rebuild if that build is broken, which
      # is often exactly why it isn't cached). We only want the hash chars.
      path = builtins.unsafeDiscardStringContext drv.outPath;
      hash = lib.head (lib.splitString "-" (baseNameOf path));
      probe = pkgs.runCommandLocal "cache-status-${hash}"
        {
          nativeBuildInputs = [ pkgs.curl pkgs.cacert ];
          day = toString (builtins.currentTime / 86400);
        }
        ''
          code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
            "https://cache.nixos.org/${hash}.narinfo" || echo 000)
          case "$code" in
            200) printf cached  > "$out" ;;
            404) printf missing > "$out" ;;
            *)   printf unknown > "$out" ;;
          esac
        '';
    in
    lib.fileContents probe;

in

{ name, rev, sha256 }:
let
  pinnedPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  }) {
    localSystem = system;
    inherit (pkgs) config;
  };

  pinned = pinnedPkgs.${name};
  current = pkgs.${name};
  currentRev = lib.trivial.revisionWithDefault "unknown";
  status = cacheStatus current;

  report = {
    cached = "✅ cache.nixos.org has ${name} ${current.version} (${system}) — safe to remove this pin";
    missing = "❌ cache.nixos.org has no ${name} ${current.version} (${system}) build yet — keep this pin";
    unknown = "❓ couldn't reach cache.nixos.org — cache status for ${name} ${current.version} unknown, keeping pin";
  };

  message = ''
    pinned ${name} ${pinned.version} (nixpkgs ${short rev}) over current ${current.version} (nixpkgs ${short currentRev})
      ${report.${status}}'';
in
lib.warn message pinned
