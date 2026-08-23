# Backport candidates

Fixes made on this branch (`migration-flake`) that are worth applying to the
**pre-migration** setup too — i.e. `macos` master and the `dot` / `private`
castles — because `newt` runs that setup until phase 3 (see `MIGRATION.md`).

Nothing here is required for the migration itself. This is the list of "I found
a real bug while migrating and my daily driver still has it."

Format: what, why it matters before the migration lands, and where it goes.

---

## 1. `OP_CONFIG_DIR` pointed at the private castle — **highest value**

**Commit here:** `f05e569`

`op`'s config holds *device-local* state: account registrations keyed to a
per-device UUID. Pointing every machine at one synced copy in the private
castle makes them fight — each machine's signin invalidates the others'. This
surfaced provisioning Ala, where `homeshick link private` replaced the freshly
created `~/.config/op/config` with a symlink to newt's state and broke `op`.

This is live on `newt` right now, and it gets worse with each additional
machine.

Confirmed broken on `newt`, not merely untidy — against the redirected config
`op` cannot resolve its own session:

```
$ op whoami
[ERROR] multiple accounts found. Use the --account flag or …
$ OP_CONFIG_DIR=~/.config/op op whoami
URL: https://rolfers.1password.com/   # works
```

Both configs register the same two accounts, so what the redirect loses is the
desktop-app integration state that lets `op` pick one. Any tool shelling out to
`op` without an explicit account fails here today.

**Backport to:**
- `dot`: drop `export OP_CONFIG_DIR=...` from `home/.zshenv`
- `dot`: drop the `OP_CONFIG_DIR` entry from
  `home/.config/glide/one-password.ts`'s `OP_ENV`
- `private`: `git rm --cached home/.config/op/config` (device-local). Keep
  `home/.config/op/plugins/gh.json` — it's item UUIDs, which are portable.

---

## 2. Private Homebrew tap can't clone on a fresh machine

**Commit here:** `3f4c47d`

`meterup/homebrew-packages` is private, and brew taps over HTTPS with
`GIT_TERMINAL_PROMPT=0`, so a machine without a cached GitHub credential fails
with `could not read Username`, taking `mcurl` / `mctl` / `hostsfile` down with
it. It only works on newt because a credential happens to sit in the keychain
(plus `credential.helper = !gh auth git-credential` in the git config) — none of
which is reproducible.

Fix: pin the tap to SSH so it uses the SSH key the machine already has.

```nix
{
  name = "meterup/packages";
  clone_target = "git@github.com:meterup/homebrew-packages.git";
  trusted = true;
}
```

**Backport to:** `macos` master, `home/.nixpkgs/homebrew.nix`. Requires a
nix-darwin with attrset taps — master already uses `{ name = …; trusted = …; }`,
so `clone_target` should be available too. Verify before relying on it.

---

## 3. Duplicate `insteadOf` in the git config

**Commit here:** (this commit)

`home/.config/git/config` declared the same rewrite twice with different
targets:

```
[url "git@github.com:"]        insteadOf = https://github.com/
[url "ssh://git@github.com/"]  insteadOf = https://github.com/
```

Identical `insteadOf` values mean which one wins is effectively arbitrary.
Harmless in practice (both resolve to the same SSH clone) but confusing.
Removed the `ssh://` form, kept the documented scp-form one.

**Backport to:** `dot`, `home/.config/git/config`.

---

## 4. Two inert lines in the kitty config

**Commit here:** (this commit)

Both are live on `newt` today, and both fail silently.

`kitty.conf`'s `symbol_map` had its value on the following line. kitty has no
line continuation, so the key parsed with an empty value and the codepoints
parsed as a key of their own — `Ignoring invalid config line` twice, mapping
inert. Nerd Font glyphs still render because kitty falls back to any installed
font that has them, so the only symptom is that *which* font supplies them is
whatever Core Text picks. Joining the line also needed the family name fixed
(`JetbrainsMono Nerd Font` matches nothing; the cask installs
`JetBrainsMono Nerd Font Mono`) and three ranges trimmed to what that font's
cmap actually covers — Nerd Fonts v3 moved Material Design Icons out of
`U+F500-U+FD46` to the `U+F0001-U+F1AF0` plane.

`sessions/startup.conf`'s `source ~/.config/zsh/init/keys.zsh` is not a kitty
session directive — the parser has no `source` (checked in 0.47.2 and on kitty
master), so it's rejected with `Unknown command in session file`. It's also
unnecessary: `.zshrc` snippets every `$XDG_CONFIG_HOME/zsh/init/*.zsh`, which is
where `private` plants `keys.zsh`.

**Backport to:** `dot`, `home/.config/kitty/kitty.conf` and
`home/.config/kitty/sessions/startup.conf`.

---

## Explicitly *not* backport candidates

- **Dropping `homebrew.onActivation.extraFlags = [ "--force-cleanup" ]`.** On
  this branch nix-darwin passes it itself, so ours was a duplicate. Master pins
  an older nix-darwin that does *not*, so master still needs it. Leave alone;
  it resolves itself when master's nix-darwin advances (or at phase 3).
- **Removing the `insteadOf` unset/restore dance from `homebrew.nix`**
  (`bf9b60f`). Only safe here because a bootstrapped machine has a
  passphraseless `~/.ssh/id_ed25519` that needs no agent, and because
  `clone_target` now covers the private tap. Newt's SSH is gpg-agent-backed, so
  the workaround may still be doing real work there.
- **Anything that only exists because of the flake layout** — pure-eval fixes
  (`getEnv` → `specialArgs`, `builtins.currentTime` in `pin.nix`),
  `$NIX_CONFIG_DIR` in `tap.nix`, registry pins. These are migration artifacts,
  meaningless pre-migration.
