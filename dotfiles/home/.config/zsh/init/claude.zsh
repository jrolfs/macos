# ╌╌↘
#
# Resume a Claude Code thread that was started by Zed's ACP client. The built-in
# `/resume` picker mixes these in with terminal sessions and is scoped to the
# current directory; Zed history is siloed per working directory, so threads
# started elsewhere never show. This narrows to just the Zed threads and can
# widen the search across the repo or everything, reattaching the chosen one
# from its own home directory.
#
# ```sh
#   resume-zed          # threads for this project directory
#   resume-zed --repo   # every git worktree of the current repo
#   resume-zed --all    # every project on disk
#   resume-zed -d PATH  # a different project directory
# ```
#
# ╌╌↗
resume-zed() {
  local script="${HOME}/.claude/bin/claude-zed-threads"
  [[ -x "$script" ]] || { print -u2 "resume-zed: missing or non-executable $script"; return 1 }

  # Map each clean display line back to its session id and home directory, so
  # the picker never has to surface (or parse fields out of) the raw uuid.
  local -A id_for dir_for
  local -a order
  local id dir display
  while IFS=$'\t' read -r id dir display; do
    id_for[$display]=$id
    dir_for[$display]=$dir
    order+=("$display")
  done < <("$script" --sk "$@")

  (( ${#order} )) || { print -u2 "resume-zed: no Zed/ACP threads found"; return 0 }

  local choice
  choice=$(print -rl -- "${order[@]}" \
    | sk --prompt='zed thread ❯ ' --height=40% --reverse) || return 0
  [[ -n "$choice" ]] || return 0

  # Reattach from the thread's own directory when it still exists, so file
  # references in the transcript resolve; otherwise resume in place.
  local home_dir="${dir_for[$choice]}"
  [[ -n "$home_dir" && -d "$home_dir" ]] && cd "$home_dir"
  claude --resume "${id_for[$choice]}"
}
