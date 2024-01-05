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
# Usage: id=$(_deconz_sensor_clip id name type [swversion])
function _deconz_sensor_clip()
{
  local response
  local -i id

  id=$(deconz_unquote $(deconz post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"${3}\",
    \"modelid\": \"${3}\",
    \"manufacturername\": \"homebridge-deconz\",
    \"swversion\": \"${4:-0}\",
    \"uniqueid\": \"/sensors/${1}\"
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
  _deconz_sensor_clip "${1}" "${2}" CLIPGenericFlag "${version}"
}

# Create CLIPGenericStatus sensor.
# swversion is used to indicate to homebridge-deconz what the minimum and maximum
# allowed values for the status are.
# Usage: id=$(deconz_sensor_clip_status id name [min max]])
function deconz_sensor_clip_status() {
  _deconz_sensor_clip "${1}" "${2}" CLIPGenericStatus "${3:-0},${4:-2}"
}

# Create CLIPPresence sensor.
# Usage: id=$(deconz_sensor_clip_presence id name)
function deconz_sensor_clip_presence() {
  _deconz_sensor_clip "${1}" "${2}" CLIPPresence
}

# Create CLIPLightLevel sensor.
# Usage: id=$(deconz_sensor_clip_lightlevel id name [tholddark tholdoffset])
function deconz_sensor_clip_lightlevel() {
  local -i id=$(_deconz_sensor_clip "${1}" "${2}" CLIPLightLevel)
  [ $? -eq 0 ] || return 1
  deconz put "/sensors/${id}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
  echo "${id}"
}

# Create CLIPTemperature sensor.
# Usage: id=$(deconz_sensor_clip_temperature id name)
function deconz_sensor_clip_temperature() {
  _deconz_sensor_clip "${1}" "${2}" CLIPTemperature
}

# Create CLIdeconzumidity sensor.
# Usage: id=$(deconz_sensor_clip_humidity id name)
function deconz_sensor_clip_humidity() {
  _deconz_sensor_clip "${1}" "${2}" CLIdeconzumidity
}

# Create CLIPPressure sensor.
# Usage: id=$(deconz_sensor_clip_pressure id name)
function deconz_sensor_clip_pressure() {
  _deconz_sensor_clip "${1}" "${2}" CLIPPressure
}

# Create CLIPOpenClose sensor.
# Usage: id=$(deconz_sensor_clip_openclose id name)
function deconz_sensor_clip_openclose() {
  _deconz_sensor_clip "${1}" "${2}" CLIPOpenClose
}

# Create MultiCLIP resourcelink.
# Usage: id=$(deconz_sensor_multiclip id [id...])
function deconz_sensor_multiclip() {
  deconz delete "/resourcelinks/${1}" >/dev/null 2>&1
  local links="\"/sensors/${1}\""
  local -i one="${1}"
  shift
  for i in "${@}" ; do
    links="${links}, \"/sensors/${i}\""
  done
  local -i id=$(deconz_unquote $(deconz post "/resourcelinks" "{
    \"name\": \"homebridge-hue\",
    \"description\": \"multiclip\",
    \"classid\": 1,
    \"links\": [${links}]
  }"))
  [ $? -ne 0 ] && return 1
  _deconz_info "/resourcelinks/${id}: multiclip"
  [ ${id} -ne ${one} ] && _deconz_warn "/resourcelinks/${id}: not requested id ${one}"
  echo ${id}
}

# Create MultiLight resourcelink.
# Usage: id=$(deconz_light_multilight id [id...])
function deconz_light_multilight() {
  deconz delete "/resourcelinks/${1}" >/dev/null 2>&1
  local links="\"/lights/${1}\""
  local -i one="${1}"
  shift
  for i in "${@}" ; do
    links="${links}, \"/lights/${i}\""
  done
  local -i id=$(deconz_unquote $(deconz post "/resourcelinks" "{
    \"name\": \"homebridge-hue\",
    \"description\": \"multilight\",
    \"classid\": 1,
    \"links\": [${links}]
  }"))
  [ $? -ne 0 ] && return 1
  _deconz_info "/resourcelinks/${id}: multilight"
  [ ${id} -ne ${one} ] && _deconz_warn "/resourcelinks/${id}: not requested id ${one}"
  echo ${id}
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
    \"sensitivity\": ${3:-2}
  }"
  [ $? -eq 0 ] || return 1
  if [ "${_deconz_model}" != "deCONZ" ] ; then
    id=$(deconz_unquote $(deconz post /resourcelinks "{
      \"name\": \"${2}\",
      \"classid\": 10010,
      \"links\": [ \"/sensors/${1}\" ]
    }"))
    _deconz_info "/resourcelinks/${id}: ${2}"
  fi
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
  [ "${_deconz_model}" == "deCONZ" ] || return 0
  deconz put "/sensors/${1}/config" "{
    \"offset\": ${3:-0}
  }"
}
