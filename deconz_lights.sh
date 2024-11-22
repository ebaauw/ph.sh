#!/bin/bash
#
# deconz_lights.sh
# Copyright © 2024 Erik Baauw. All rights reserved.
#
# Create/configure lights on a deCONZ gateway.
# Note: be sure to re-create rules after re-creating sensors.

. deconz.sh
if [ $? -ne 0 ] ; then
  _deconz_error "cannot load deconz.sh"
  return 1
fi

# ===== ZIGBEE LIGHTS =========================================================

# Set light name.
# Usage: deconz_light_name id name
function deconz_light_name() {
  deconz put "/lights/${1}" "{
    \"name\": \"${2}\"
  }"
  [ $? -eq 0 ] || return 1
  local type=$(deconz get /lights/${1}/type)
  _deconz_info "/lights/${1}: ${type} \"${2}\""
}
