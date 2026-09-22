import os
import subprocess

from kittens.tui.operations import styled

# Absolute path because the kitten inherits kitty's environment, which is not
# guaranteed to have the nix profile on PATH.
ZOXIDE = "/run/current-system/sw/bin/zoxide"


def main(_):
    try:
        return input(
            styled("󰩷 ", fg="cyan")
            + styled("z➝ ", fg="black", fg_intense=True, bold=True)
        )
    except (EOFError, KeyboardInterrupt):
        return ""


def resolve(keywords):
    # `__zoxide_z` treats a lone argument that names a real directory as a
    # literal path rather than a database query.
    if len(keywords) == 1:
        literal = os.path.expanduser(keywords[0])
        if os.path.isdir(literal):
            return os.path.abspath(literal)

    query = subprocess.run(
        [ZOXIDE, "query", "--", *keywords],
        capture_output=True,
        text=True,
        check=False,
    )
    if query.returncode != 0:
        return ""

    return query.stdout.strip()


def handle_result(_, answer, target_window_id, boss):
    keywords = answer.split()
    if not keywords:
        return

    # Resolve the directory here instead of asking an interactive login shell
    # to run `__zoxide_z` and then exec the real shell. That shell ran .zlogin
    # before exec'ing, so every tab printed the welcome banner twice and paid
    # for .zshrc twice.
    target = resolve(keywords) or os.path.expanduser("~")

    # zoxide's zsh hook is registered on chpwd only, so a shell that starts in
    # the directory never records the visit.
    subprocess.run([ZOXIDE, "add", "--", target], check=False)

    window = boss.window_id_map.get(target_window_id)
    boss.call_remote_control(
        window,
        (
            "launch",
            "--type=tab",
            "--add-to-session",
            ".",
            f"--cwd={target}",
        ),
    )
