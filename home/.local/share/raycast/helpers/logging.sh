# Helper function for adding timestamps to log output
#
# Usage:
# ```sh
# exec 2> >(add_timestamp >>"$logs")
# ```
function add_timestamp {
  while IFS= read -r line; do
    echo "$(date): $line"
  done
}
