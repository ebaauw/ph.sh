#!/bin/bash
#
# deconz_sensors.sh
# Copyright © 2017-2024 Erik Baauw. All rights reserved.
#
# Create/configure sensors on a deCONZ gateway.
# Note: be sure to re-create rules after re-creating sensors.

. deconz.sh
if [ $? -ne 0 ] ; then
  _deconz_error "cannot load deconz.sh"
  return 1
fi

# ===== CLIP SENSORS ===========================================================

# Create (Multi)CLIP sensor.
# To reduce the number of HomeKit accessories, homebridge-deconz can combine
# multiple CLIP sensor resources with the same MultiCLIP id (mid) into one
# accessory.  Typically you'll want to use one MultiCLIP sensor per room, as
# HomeKit does room assignment per accessory.
# Provide an empty mid ("") to have homebridge-hue create a separate accessory
# for the CLIP sensor resource.
# Usage: id=$(_deconz_sensor_clip id name type uniqueid [swversion])
function _deconz_sensor_clip()
{
  local response
  local -i id

  id=$(deconz_unquote $(deconz post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"${3}\",
    \"modelid\": \"${3}\",
    \"manufacturername\": \"homebridge-deconz\",
    \"swversion\": \"${5:-0}\",
    \"uniqueid\": \"${4:-S${1}}\"
  }"))
  [ $? -ne 0 ] && return 1
  _deconz_info "/sensors/${id}: ${3} \"${2}\""
  [ ${id} -ne ${1} ] && _deconz_warn "/sensors/${id}: not requested id ${1}"
  echo ${id}
}

# Create CLIPGenericFlag sensor.
# swversion is used to indicate to homebridge-deconz whether the sensor should be
# read-only ("0") or read-write ("1") from HomeKit apps.
# Usage: id=$(deconz_sensor_clip_flag id name [readonly])
function deconz_sensor_clip_flag() {
  local version=1

  [ -z "${3}" ] || version=0
  _deconz_sensor_clip "${1}" "${2}" CLIPGenericFlag  "S${1}-01-0006" "${version}"
}

# Create CLIPGenericStatus sensor.
# swversion is used to indicate to homebridge-deconz what the minimum and maximum
# allowed values for the status are.
# Usage: id=$(deconz_sensor_clip_status id name [aid] [min max]])
function deconz_sensor_clip_status() {
  _deconz_sensor_clip "${1}" "${2}" CLIPGenericStatus "${3:-${1}}-01-0012" "${4:-0},${5:-2}"
}

# Create CLIPPresence sensor.
# Usage: id=$(deconz_sensor_clip_presence id name [aid])
function deconz_sensor_clip_presence() {
  _deconz_sensor_clip "${1}" "${2}" CLIPPresence "S${3:-${1}}-01-0406"
}

# Create CLIPLightLevel sensor.
# Usage: id=$(deconz_sensor_clip_lightlevel id name [aid] [tholddark tholdoffset])
function deconz_sensor_clip_lightlevel() {
  local -i id=$(_deconz_sensor_clip "${1}" "${2}" CLIPLightLevel "S${3:-${1}}-01-0400")
  [ $? -eq 0 ] || return 1
  deconz put "/sensors/${id}/config" "{
    \"tholddark\": ${4:-12000},
    \"tholdoffset\": ${5:-4000}
  }"
  echo "${id}"
}

# Create CLIPTemperature sensor.
# Usage: id=$(deconz_sensor_clip_temperature id name [aid])
function deconz_sensor_clip_temperature() {
  _deconz_sensor_clip "${1}" "${2}" CLIPTemperature "S${3:-${1}}-01-0402"
}

# Create CLIdeconzumidity sensor.
# Usage: id=$(deconz_sensor_clip_humidity id name [aid])
function deconz_sensor_clip_humidity() {
  _deconz_sensor_clip "${1}" "${2}" CLIPhumidity "S${3:-${1}}-01-0405"
}

# Create CLIPPressure sensor.
# Usage: id=$(deconz_sensor_clip_pressure id name [aid])
function deconz_sensor_clip_pressure() {
  _deconz_sensor_clip "${1}" "${2}" CLIPPressure "S${3:-${1}}-01-0403"
}

# Create CLIPOpenClose sensor.
# Usage: id=$(deconz_sensor_clip_openclose id name [aid])
function deconz_sensor_clip_openclose() {
  _deconz_sensor_clip "${1}" "${2}" CLIPOpenClose "S${3:-${1}}-01-0500"
}

# ===== ZIGBEE SENSORS =========================================================

# Set sensor name.
# Usage: deconz_sensor_name id name
function deconz_sensor_name() {
  deconz put "/sensors/${1}" "{
    \"name\": \"${2}\"
  }"
  [ $? -eq 0 ] || return 1
  local type=$(deconz_unquote $(deconz get "/sensors/${1}/type"))
  _deconz_info "/sensors/${1}: ${type} \"${2}\""
}

# Set Hue Motion presence sensor name, sensitivity, and resourcelink.
# Hue app v2 expects a resourcelink before it shows Hue Motion status.
# Usage: deconz_sensor_presence id name [sensitivity]
function deconz_sensor_presence() {
  local -i id

  deconz_sensor_name "${1}" "${2}"
  [ $? -ne 0 ] && return 1
  deconz put "/sensors/${1}/config" "{
    \"sensitivity\": ${3:-4}
  }"
}

# Set Hue Motion lightlevel sensor name and thresholds.
# Usage: deconz_sensor_lightlevel id name [tholddark tholdoffset]
function deconz_sensor_lightlevel() {
  deconz_sensor_name "${1}" "${2}"
  [ $? -eq 0 ] || return 1
  deconz put "/sensors/${1}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
}

# Set Hue Motion temperature sensor name and offset.
# Usage: deconz_sensor_temperature id name [offset]
function deconz_sensor_temperature() {
  deconz_sensor_name "${1}" "${2}"
  [ $? -eq 0 ] || return 1
  deconz put "/sensors/${1}/config" "{
    \"offset\": ${3:-0}
  }"
}
