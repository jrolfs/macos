# Migration: homeshick + channels → flakes + home-manager

Durable record of the migration this repo is undergoing. (The Claude Code
plan files under `~/.claude/plans/` are ephemeral; this file is the source
of truth.)

## Goal

Collapse four homeshick castles (`macos`, `dot`, `neovim`, `private`) plus a
channels-based nix-darwin config into **one flake** that configures every
machine — macOS and the NixOS NUC — from a single source, with home-manager
owning the dotfiles.

## Architecture

- **One repo.** This repo (currently the `migration-flake` branch; deploys to
  `~/.config/system` on a machine). `flake.nix` exposes:
  - `darwinConfigurations.ala` — new MacBook (phase 1 target)
  - `darwinConfigurations.newt` — daily driver (phase 3, added last)
  - `nixosConfigurations.irulan` — Beelink NUC home server (phase 2)
- **`dot` subtree-merged** into `dotfiles/` with full history. The old `macos`
  castle's `home/` was consolidated in beside it. `modules/home/*` symlinks the
  tree into `$HOME` (lift-and-shift by default; `programs.git`/`direnv`/
  `starship`/`atuin` translated where it paid off; `zed`/`karabiner`/`vscode`/
  `cursor` via `mkOutOfStoreSymlink` so the apps can write back).
- **`neovim`** stays its own repo, consumed as a `flake = false` input
  (`inputs.neovim-config`), symlinked with `recursive = true` so runtime state
  can live beside the config.
- **`private`** stays a homeshick castle (git-crypt). `$HOMESHICK_KINGDOM` is
  still exported so `OP_CONFIG_DIR` etc. resolve.
- **Submodules dropped.** nix-darwin / nixpkgs are flake inputs pinned to
  upstream; the custom Homebrew tap lives in-repo as plain files (`homebrew/`).

### Layout

```
flake.nix / flake.lock
hosts/{ala,newt,irulan}/default.nix    # per-host
modules/darwin/                        # nix-darwin modules (was home/.nixpkgs/)
modules/nixos/{default.nix,services/}  # NixOS (Irulan)
modules/home/{default,darwin,linux}.nix + hosts/<host>.nix
overlays/{default.nix,pin.nix}         # overlay + pin helper
homebrew/                              # dehydrated tap (plain files)
dotfiles/home/…                        # the merged dotfile tree
icons/                                 # custom app-icon assets + apply.sh
MIGRATION.md
```

## Key conventions / gotchas

- **`builtins.getEnv` returns `""` under pure flake eval.** Replaced everywhere:
  `icons.nix`/`spicetify.nix` derive `xdgDataHome` from `specialArgs.userName`;
  `homebrew.nix` uses a per-host `excludeByHost` attrset keyed on `hostname`.
- **`builtins.currentTime` is unavailable under pure flake eval** (channels
  allowed it). `overlays/pin.nix` dropped its `day`-bucket; the cache-probe
  derivation is named `cache-status-${hash}` so it re-runs when the pinned
  package's current build changes — the right time to re-check anyway.
- **`nix.package = pkgs.lixPackageSets.lix_2_94.lix`** — Lix 2.95 dropped
  `builtins.fetchClosure`, which devbox needs. Revert to `pkgs.lix` once devbox
  repos move to devenv.
- **`tap.nix`** cask-updater writes to the working tree → uses `$NIX_CONFIG_DIR`
  (set via `home.sessionVariables`), never `${self}` (read-only store path).
- **icon-customizer FDA**: `/usr/local/bin/icon-customizer` is a stable-path
  Mach-O wrapper so the Full Disk Access grant survives rebuilds. Sudoers rule
  for `icon-setter` is now declared via `environment.etc` (nix-darwin keeps it
  in lockstep with the store path). Grant FDA once after the first switch.
- **Registry + NIX_PATH**: `nix.registry.nixpkgs.flake = inputs.nixpkgs` and a
  flake-pinned `nix.nixPath` keep both `nix shell nixpkgs#foo` and
  `nix-shell -p foo` working.

## Pinning / overlays

- **`overlays/pin.nix`** — pin a single package to an older nixpkgs revision
  (via `builtins.fetchTarball`) when the current rev isn't cached yet
  (aarch64-darwin lags). Prints live cache status each rebuild so you know when
  the pin is safe to remove.
- **`masterPkgs`** — `inputs.nixpkgs-master` provides bleeding-edge builds
  (e.g. `spicetify-cli`). Bump with `nix flake update nixpkgs-master`.
- **`zshcs`** (Zsh LSP) — built by the overlay from `inputs.zshcs`
  (`flake = false`). Was previously pinned via npins; **npins was dropped** —
  everything is flake-managed now.
- Overrides that disable sandbox-hostile/naive tests when building from source:
  `mcp-nixos` (`test_read_text_file`), `worktrunk` (process-table probes).

### Reference — pinning old package versions

`nixpkgs-multiverse` (https://fzakaria.com/2026/08/09/nixpkgs-multiverse-every-version-that-ever-existed)
makes every historical nixpkgs version addressable — worth trying if `pin.nix`
becomes unwieldy or a package needs a precise old version. Not adopted yet.

## Bootstrap (`jrolfs/bootstrap`, `flake-migration` branch)

Fresh-machine installer, two stages: `bootstrap.sh` (bash) installs **Lix** +
Xcode CLT and clones itself (`BOOTSTRAP_REF` selects the branch — use
`flake-migration` until it merges to `main`), then a Deno/TS app runs an
ordered, resumable set of phases (state in `~/.bootstrap/state.json`; re-run
the one-liner to resume). macOS-only steps are gated on `Deno.build.os`.

Run it on a fresh machine:

```sh
BOOTSTRAP_REF=flake-migration bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/jrolfs/bootstrap/flake-migration/bootstrap.sh)"
```

Phases, in order:
1. **hostname-set** — confirm/set the hostname *first* (the flake selects its
   host config by it). macOS sets HostName + LocalHostName + ComputerName +
   flushes DNS; Linux uses `hostnamectl`. The chosen name is persisted and used
   for the flake selector, not a live re-read (a fresh Mac's `hostname` is often
   a DHCP/marketing name, not e.g. `ala`).
2. **github-authed** — device-flow auth, mint + upload an SSH key.
3. **homebrew-installed** → **op-installed** → **op-authenticated** (enable the
   1Password GUI's CLI integration; verified via `op whoami`).
4. **private-cloned** (homeshick clone + `link private`) → **nix-config-cloned**
   (`nixConfigRepo`@`nixConfigBranch` → `~/.config/system`; currently
   `jrolfs/macos`@`migration-flake` — flip the repo name after the rename) →
   **vscode-sync-cloned**.
5. **resilio-configured** — install Resilio, best-effort seed `sync.conf`, launch
   foreground and **guide the user** through the first-run EULA + adding the
   `~/Configuration` share (secret pulled via `op`, shown on screen). The GUI app
   manages folders in its own storage, so the manual add is surfaced with a
   pause rather than assumed. Then wait for `~/Configuration/mackup` to sync.
6. **first-switch-completed** — `darwin-rebuild`/`nixos-rebuild switch --flake
   ~/.config/system#<hostname>` (first run bootstraps the tool via `nix run`).
7. **mackup-restored** — confirmed `mackup restore -f` from the synced
   `~/Configuration/mackup` (mackup is installed by the switch). Skips cleanly if
   not ready; `mkrs` remains available.

Post-switch: grant Full Disk Access to `/usr/local/bin/icon-customizer`.

## Phases

1. **Ala** (new Mac) — flake conversion + home-manager + dotfile audit.
   `darwin-rebuild build --flake .#ala` is the gate; then bootstrap a clean Ala.
2. **Irulan** (NixOS NUC, Beelink SEi 12 / i5-12450H) — home-server workload off
   the QNAP. Native `services.{home-assistant,plex,step-ca}`; Komodo core+mongo
   +periphery as bootstrap-tier `virtualisation.oci-containers`; traefik/pi-hole
   /matter stay Komodo-deployed from the compose repo. Plex uses Quick Sync
   (`hardware.graphics` + `intel-media-driver`); media over NFS from the QNAP;
   Pi-hole keeps its LAN IP via macvlan. `hosts/irulan/hardware-configuration.nix`
   is generated on the box at install time. See `modules/nixos/services/`.
3. **Newt** (daily driver) — migrated last, once Ala + Irulan are proven.
   Back up `~/.homesick`, `homeshick unlink dot macos` (leave `private`),
   `mv ~/.homesick/repos/macos ~/.config/system`, add `hosts/newt/`, switch.
   Consider `cleanup = "uninstall"` (not `zap`) for the first switch.

## Keeping up with drift (until phase 3)

The old `dot` / `macos` `master` branches are still edited via homeshick until
Newt migrates, so periodic forward-ports are needed:

- **neovim**: `nix flake update neovim-config`.
- **dot** (content, no moves): merge `master` into the `audit-cleanup` branch,
  then `git subtree pull --prefix=dotfiles <dot> audit-cleanup`. Expect a
  `.zshrc` conflict on the zinit source line — keep `$XDG_DATA_HOME/zinit/…`,
  take dot's other additions.
- **macos**: the migration *moved* these files, so don't cherry-pick — re-derive
  `modules/darwin/*` from `home/.nixpkgs/*` and re-apply the transforms above,
  and copy changed dotfiles from `home/*` into `dotfiles/home/*` and
  `icons/` / `homebrew/` / `.mcp.json` at the root.

Retire the homeshick-on-old-repos workflow soon to end the catch-up treadmill.
