#!/bin/sh

if [ ! -d "/etc/genmon" ]; then
  mkdir -p /etc/genmon
fi

# Recreate the module log dir in case a volume is mounted over /var/log
mkdir -p /var/log/genmon

# Call genloader directly with the virtualenv python: startgenmon.sh wraps the
# same call in sudo, which is unavailable (and unnecessary) as a non-root user.
/app/genmon/genenv/bin/python /app/genmon/genloader.py -s && tail -F /var/log/genmon.log
