function setup() {
  export AUTOMATOR_LOGS=/tmp/raycast/automator
  export AUTOMATOR_WORKFLOWS="${XDG_DATA_HOME}/automator"

  mkdir -p $AUTOMATOR_LOGS

  local logs="${AUTOMATOR_LOGS}/$1.log"

  echo "====================================== $(date) ======================================" >> $logs

  # exec 1>>$logs 2>&1
  exec 2>>$logs
}
