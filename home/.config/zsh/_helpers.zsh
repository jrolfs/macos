[[ -n "$__JR_ZSH_DARWIN_HELPERS" ]] && return 0; __JR_ZSH_DARWIN_HELPERS=1

#
# Display

# Color

brightblack_() {
  echo "\033[2m${1}\033[0m"
}

# Format

bold_() {
  echo "\033[1m${1}\033[0m"
}

italic_() {
  echo "\033[3m${1}\033[0m"
}

code_() {
  echo "$(bold_ $(brightblack_ $1))"
}

# Remove leading whitespace (including newlines, spaces, and tabs)
trim_() {
  echo "$1" | awk '{
    sub(/^[ \t\r\n]+/, "", $0);
    sub(/[ \t\r\n]+$/, "", $0);
    print
  }'
}

json_() {
  echo "$1" | jq .
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'

  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done

  printf "    \b\b\b\b"
}

#
# Data

url_encode() {
  printf '%s' "$1" | jq -sRr @uri
}
