#!/bin/bash
#
# deconz_keepalive.command
# Copyright © 2020-2025 Erik Baauw. All rights reserved.
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
status=$(deconz get /sensors/${CLIP_STATUS}/state/status)
if [ ${status} -lt 1 -o ${status} -gt 3 ] ; then
  echo "$(date): status: ${status} - automated room update disabled"
  exit 0
fi

# Update room status.
statusName=$(deconz get /sensors/${CLIP_STATUS}/name)
echo "$(date): status: ${status}, idleTime: ${idleTime} - update ${statusName}"
deconz put /sensors/${CLIP_STATUS}/state '{"status": 1}'
