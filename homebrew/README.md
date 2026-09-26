# homebrew/

The `jrolfs/tap` casks. **This directory is the tap**: activation symlinks it
to `$(brew --prefix)/Library/Taps/jrolfs/homebrew-tap`, so brew reads the
working tree directly and an edit here is live on the next switch.

Bump a cask with `cask-updater` (see `modules/darwin/tap.nix`), which follows
each `url`, hashes what it gets, reads the version out of the app bundle, and
rewrites the `.rb` in place. Then commit. There is nothing else to push.

## Why it used to be harder

`homebrew.taps` named `jrolfs/tap` with no `clone_target`, so brew cloned
[`jrolfs/homebrew-tap`][tap] and read *that*, while `cask-updater` rewrote the
files here. Two copies, no sync. They drifted in both directions — the clone
was a `lingon-pro` bump ahead while this tree was a `unite-pro` fix ahead —
and a switch kept failing a checksum that had already been corrected in the
only place anyone thought to look.

The GitHub repo is now a mirror, kept so `brew tap jrolfs/tap` still works on
a machine this config doesn't manage. It is not what these machines read.

[tap]: https://github.com/jrolfs/homebrew-tap
