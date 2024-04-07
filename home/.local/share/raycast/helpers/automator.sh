source "$(dirname $0)/automator.sh"

function setup() {
  export AUTOMATOR_LOGS=/tmp/raycast/automator
  export AUTOMATOR_WORKFLOWS="${XDG_DATA_HOME}/automator"

  mkdir -p $AUTOMATOR_LOGS

  local logs="${AUTOMATOR_LOGS}/$1.log"

  # exec 2>>$logs
  exec 2> >(add_timestamp >>"$logs")
}

function run_automator() {
  automator "$AUTOMATOR_WORKFLOWS/$1.workflow"
}
