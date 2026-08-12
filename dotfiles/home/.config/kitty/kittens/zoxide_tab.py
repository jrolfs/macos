from kittens.tui.operations import styled


def main(_):
    try:
        return input(
            styled("󰩷 ", fg="cyan")
            + styled("z➝ ", fg="black", fg_intense=True, bold=True)
        )
    except (EOFError, KeyboardInterrupt):
        return ""


def handle_result(_, answer, target_window_id, boss):
    query = answer.strip()
    if not query:
        return

    window = boss.window_id_map.get(target_window_id)
    boss.call_remote_control(
        window,
        (
            "launch",
            "--type=tab",
            "--add-to-session",
            ".",
            "--cwd=~",
            "/run/current-system/sw/bin/zsh",
            "--login",
            "-i",
            "-c",
            f"__zoxide_z {query}; exec zsh --login -i",
        ),
    )
