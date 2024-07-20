source "$XDG_CONFIG_HOME/zsh/_helpers.zsh"

# Wrapper around GitHub's `gh` that launches Raycast
#
# ghr
# └─pr
#   ├─view
#   └─create
#
ghr() {
  # Function to print usage
  usage() {
    echo "Usage: ghr <command> <subcommand>"
    echo
    echo "Commands:"
    echo "  pr    Manage pull requests"
    echo
    echo "Subcommands for 'pr':"
    echo "  view    Open the current pull request in Raycast"
    echo "  create  Create a new pull request (not implemented yet)"
    echo
    echo "Examples:"
    echo "  ghr pr view    Open the current pull request in Raycast"
    echo "  ghr pr create  Create a new pull request (not implemented yet)"
  }

  # Check if gh CLI is installed
  if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it first."
    usage
    return 1
  fi

  # Check if we're in a git repositorysitory
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not in a git repositorysitory."
    usage
    return 1
  fi

  local thing=$1
  local action=$2

  local branch=$(git-branch-current)

  case "$thing" in
    pr)
      local commit=$(git rev-parse HEAD)
      local json=$(gh pr view --json number,title,url 2>/dev/null)

      local main=$(git remote show origin | awk '/HEAD branch/ {print $NF}')

      if [ -n "$json" ]; then
        local number=$(echo $json | jq -r .number)
        local pr_title=$(echo $json | jq -r .title)
        local url=$(echo $json | jq -r .url)

        local owner=$(echo $url | awk -F'/' '{print $4}')
        local repository=$(echo $url | awk -F'/' '{print $5}')
      fi

      case "$action" in
        view)
          if [ -z "$url" ]; then
            echo "No open pull request found for the current branch."
            return 1
          fi

          open "raycast://extensions/raycast/github/search-pull-requests?fallbackText=head:${branch}"
          echo "🚀 Opening $(bold_ "#$number") · $pr_title"
          ;;
        create)
          local context=$(printf \
            '{ "draftValues": { "repository": "%s", "from": "%s" } }' \
            "$owner/$repository" \
            "$branch" \
          )

					/bin/cat <<-EOF
					🚧 $(bold_ 'WIP:') still figuring out how to populate this form...

					I $(italic_ 'think') the extension would need to be updated to accept $(code_ 'arguments')
					- https://developers.raycast.com/information/lifecycle#launchprops
					- https://github.com/raycast/extensions/blob/fcdfc5a643eb998696befbf229f5a7c34533e893/extensions/github/src/create-pull-request.tsx#L26-L28

					Props:
					EOF

          echo "$(json_ $context)\n"

          echo "$(brightblack_ "raycast://extensions/raycast/github/create-pull-request?context=$(url_encode $context)")"

          echo "🌱 Creating $(bold_ $branch) → $(bold_ $main)"
          ;;
        *)
          echo "Error: Unknown pr subcommand: $action"
          usage
          return 1
          ;;
      esac
      ;;
    *)
      echo "Error: Unknown command: $thing"
      usage
      return 1
      ;;
  esac
}
