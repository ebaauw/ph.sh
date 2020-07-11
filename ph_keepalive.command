#!/bin/bash
#
# ph_keepalive.command
# Copyright © 2020 Erik Baauw. All rights reserved.
#
# Update the room status when macOS user has been active recently.

# Idle time threshold (in seconds).
IDLE_TIME=${IDLE_TIME:=300}

# Get idle time.
idleTime=$(ioreg -c IOHIDSystem | grep HIDIdleTime | cut -d = -f 2)
idleTime=$((idleTime / 1000000000))

# Get current room status.
status=$(ph get /sensors/${CLIP_STATUS}/state/status)
statusName=$(ph get /sensors/${CLIP_STATUS}/name)

if [ ${idleTime} -gt ${IDLE_TIME} ] ; then
  echo "$(date): idleTime: ${idleTime} - user inactive"
  exit 0
fi

if [ ${status} -lt 0 -o ${status} -gt 3 ] ; then
  echo "$(date): status: ${status} - automated room update disabled"
  exit 0
fi

echo "$(date): status: ${status}, idleTime: ${idleTime} - update ${statusName}"
ph put /sensors/${CLIP_STATUS}/state '{"status": 1}'
