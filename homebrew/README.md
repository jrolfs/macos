# homebrew/

Source copies of the casks in [`jrolfs/homebrew-tap`][tap], which is what
`brew` actually installs from. `cask-updater` (see `modules/darwin/tap.nix`)
reads and rewrites the files *here*.

**These files are not live.** `homebrew.taps` declares `jrolfs/tap`, so brew
clones the tap from GitHub; nothing links this directory into
`/opt/homebrew/Library/Taps/`. Editing a cask here and switching therefore
changes nothing, and the two copies drift in both directions — on 2026-09-26
the tap was a `lingon-pro` bump ahead while this directory was a `unite-pro`
fix ahead, and a switch kept failing on a checksum that looked already fixed.

So after `cask-updater`, push the result to the tap repo as well:

```sh
cask-updater                       # rewrites homebrew/Casks/*.rb in place
# then mirror the change into jrolfs/homebrew-tap and push
```

Worth collapsing one day, either by pointing `homebrew.taps` at a local path
or by dropping this directory and editing the tap repo directly. Until then,
two copies mean two commits.

[tap]: https://github.com/jrolfs/homebrew-tap
