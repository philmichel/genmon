#!/bin/bash
# Container-aware replacement for upstream startgenmon.sh, which genserv
# invokes for the web UI's start/stop/restart actions. The upstream script
# wraps every genloader.py call in sudo, which cannot elevate as UID 1000
# under no-new-privileges, so those actions silently did nothing. Restart gets special handling: an in-place
# genloader restart would leave the new daemons orphaned under PID 1 with the
# entrypoint none the wiser, so instead we touch a sentinel that start.sh
# watches -- it stops the modules and exits, letting the container supervisor
# relaunch everything with a clean process tree and freshly-read config.

python="/app/genmon/genenv/bin/python"
genmondir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path=""
action=""

while (("$#")); do
  case "$1" in
    -c)
      config_path="-c $2"
      shift 2
      ;;
    -p) # python version selector: meaningless here, always the venv python
      shift 2
      ;;
    -h)
      echo "usage: ./startgenmon.sh [-c configpath] start|stop|restart|hardstop"
      exit 0
      ;;
    start | stop | restart | hardstop)
      action="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

case "$action" in
  start)
    echo "Starting genmon python scripts"
    exec "$python" "$genmondir/genloader.py" -s $config_path
    ;;
  stop)
    echo "Stopping genmon python scripts"
    exec "$python" "$genmondir/genloader.py" -x $config_path
    ;;
  hardstop)
    echo "Hard stopping genmon python scripts"
    exec "$python" "$genmondir/genloader.py" -z $config_path
    ;;
  restart)
    echo "Restart requested; signaling the container entrypoint to exit"
    touch /tmp/.genmon-restart
    ;;
  *)
    echo "Invalid command. Valid commands are start, stop, restart or hardstop."
    exit 1
    ;;
esac

exit 0
