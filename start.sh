#!/bin/sh

if [ ! -d "/etc/genmon" ]; then
  mkdir -p /etc/genmon
fi

# Recreate the module log dir in case a volume is mounted over /var/log
mkdir -p /var/log/genmon

# Touched by startgenmon.sh when genmon asks for a restart (e.g. after saving
# settings in the web UI). /tmp may be a pod-lifetime emptyDir that survives
# container restarts, so clear any stale request from a previous run.
RESTART_SENTINEL=/tmp/.genmon-restart
rm -f "$RESTART_SENTINEL"

stop_genmon() {
  /app/genmon/genenv/bin/python /app/genmon/genloader.py -x
}

# Stop the modules cleanly when the container is asked to terminate, instead
# of letting the kernel SIGKILL them when PID 1 dies.
trap 'stop_genmon; exit 0' TERM INT

# Call genloader directly with the virtualenv python: startgenmon.sh wraps the
# same call in sudo, which is unavailable (and unnecessary) as a non-root user.
/app/genmon/genenv/bin/python /app/genmon/genloader.py -s || exit 1

tail -F /var/log/genmon.log &

# Exit on a restart request so the container supervisor relaunches us with a
# clean process tree -- genmon's own in-place restart can't work under a
# container PID 1.
while [ ! -f "$RESTART_SENTINEL" ]; do
  sleep 2
done

echo "Restart requested via startgenmon.sh; stopping modules and exiting"
stop_genmon
exit 0
