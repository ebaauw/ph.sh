#!/bin/bash
#
# ph_keepalive.command
# Copyright © 2020-2022 Erik Baauw. All rights reserved.
#
# Update the room status when macOS user has been active recently.

# Idle time threshold (in seconds).
IDLE_TIME=${IDLE_TIME:=300}

# Get idle time.
idleTime=$(ioreg -c IOHIDSystem | grep HIDIdleTime | cut -d = -f 2)
idleTime=$((idleTime / 1000000000))
if [ ${idleTime} -gt ${IDLE_TIME} ] ; then
  echo "$(date): idleTime: ${idleTime} - user inactive"
  exit 0
fi

# Get current room status.
status=$(ph get /sensors/${CLIP_STATUS}/state/status)
if [ ${status} -lt 1 -o ${status} -gt 3 ] ; then
  echo "$(date): status: ${status} - automated room update disabled"
  exit 0
fi

# Update room status.
statusName=$(ph get /sensors/${CLIP_STATUS}/name)
echo "$(date): status: ${status}, idleTime: ${idleTime} - update ${statusName}"
ph put /sensors/${CLIP_STATUS}/state '{"status": 1}'
