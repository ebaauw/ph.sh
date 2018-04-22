#!/bin/bash
#
# ph_sensors.sh
# Copyright © 2017, 2018 Erik Baauw. All rights reserved.
#
# Create/configure sensors on the Hue bridge or deCONZ gateway.
# Note: be sure to re-create rules after re-creating sensors.

. ph.sh
if [ $? -ne 0 ] ; then
  _ph_error "cannot load ph.sh"
  return 1
fi

# ===== SENSOR ID ==============================================================

# To force (re-)creation of sensors with a pre-determined resource id, we create
# dummy sensor resources to fill up all the sensor resource slots.  Before
# creating a CLIP sensor, we delete the dummy sensor for the id we want the CLIP
# sensor to have.
#
# The same approach works for adding ZigBee sensors to the Hue bridge.  Before
# searching for a new sensor, we delete the dummy sensor for the id we want the
# ZigBee sensor to have.
# The Hue motion sensor requires special attention, since it uses three
# resources.  The following steps add a Hue Motion sensor with id xx for the
# ZLLPresence resource, yy for ZLLLightLevel, and zz for ZLLTemperature:
# - ph_sensors_init
# - ph delete /sensors/zz (temperature)
# - ph post /sensors
# - reset motion sensor
# - ph delete /sensors/xx (presence)
# - ph delete /sensors/yy (lightlevel)
# - ph post /sensors
#
# For adding ZigBee sensors to deCONZ, it's probably easier just to let deCONZ
# assign sensor resource IDs, shutdown deCONZ and change the sensor IDs in the
# deCONZ database (in ~/.local/share/dresden-elektronik/deCONZ/zll.db).  I use
# sqlitebrowser for that.

# Create dummy sensors.
function ph_sensors_init() {
  local response
  local -i id

  ph_restart

  # Clear names of existing sensors.
  for id in $(ph get -al /sensors | grep /name: | cut -d / -f 2) ; do
    [ ${id} -eq 1 ] && continue
    ph put "/sensors/${id}" '{
      "name": "_dummy"
    }'
    _ph_info "/sensors/${id}: turned to dummy sensor"
  done

  # Create dummy sensors for unused sensor slots.
  while true ; do
    id=$(ph_unquote $(ph post /sensors '{
      "name": "_dummy",
      "type": "CLIPGenericFlag",
      "modelid": "_dummy",
      "manufacturername": "_dummy",
      "swversion": "0",
      "uniqueid": "_dummy"
    }' 2>/dev/null))
    [ $? -eq 0 ] || break
    _ph_info "/sensors/${id}: created dummy sensor"
  done

  # Delete existing Hue motion sensor resoucelinks.
  for id in $(ph get -al /resourcelinks | grep /classid:10010 | cut -d / -f 2) ; do
    ph delete "/resourcelinks/${id}"
    _ph_info "/resourcelinks/${id}: deleted"
  done
}

# Remove dummy sensors.
function ph_sensors_cleanup() {
  local -i id

  for id in $(ph get -al /sensors | grep /name:\"_dummy\" | cut -d / -f 2) ; do
    ph delete "/sensors/${id}"
    _ph_info "/sensors/${id}: deleted dummy sensor"
  done
  ph_restart
}

# ===== CLIP SENSORS ===========================================================

# Create (Multi)CLIP sensor.
# To reduce the number of HomeKit accessories, homebridge-hue can combine
# multiple CLIP sensor resources with the same MultiCLIP id (mid) into one
# accessory.  Typically you'll want to use one MultiCLIP sensor per room, as
# HomeKit does room assignment per accessory.
# Provide an empty mid ("") to have homebridge-hue create a separate accessory
# for the CLIP sensor resource.
# Usage: id=$(_ph_sensor_clip id name type [swversion])
function _ph_sensor_clip()
{
  local response
  local -i id

  ph delete "/sensors/${1}" >/dev/null 2>&1
  ph_restart
  id=$(ph_unquote $(ph post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"${3}\",
    \"modelid\": \"${3}\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"${4:-0}\",
    \"uniqueid\": \"/sensors/${1}\"
  }"))
  [ $? -ne 0 ] && return 1
  _ph_info "/sensors/${id}: ${3} \"${2}\""
  [ ${id} -ne ${1} ] && _ph_warn "/sensors/${id}: not requested id ${1}"
  echo ${id}
}

# Create CLIPGenericFlag sensor.
# swversion is used to indicate to homebridge-hue whether the sensor should be
# read-only ("0") or read-write ("1") from HomeKit apps.  Note: this is not yet
# implemented in to hombridge-hue.
# Usage: id=$(ph_sensor_clip_flag id name [readonly])
function ph_sensor_clip_flag() {
  local version=1

  [ -z "${3}" ] || version=0
  _ph_sensor_clip "${1}" "${2}" CLIPGenericFlag "${version}"
}


# Create CLIPGenericStatus sensor.
# swversion is used to indicate to homebridge-hue what the minimum and maximum
# allowed values for the status are.
# Usage: id=$(ph_sensor_clip_status id name [min max]])
function ph_sensor_clip_status() {
  _ph_sensor_clip "${1}" "${2}" CLIPGenericStatus "${3:-0},${4:-2}"
}

# Create CLIPPresence sensor.
# Usage: id=$(ph_sensor_clip_presence id name)
function ph_sensor_clip_presence() {
  _ph_sensor_clip "${1}" "${2}" CLIPPresence
}

# Create CLIPLightLevel sensor.
# Usage: id=$(ph_sensor_clip_lightlevel id name [tholddark tholdoffset])
function ph_sensor_clip_lightlevel() {
  local -i id=$(_ph_sensor_clip "${1}" "${2}" CLIPLightLevel)
  [ $? -eq 0 ] || return 1
  ph put "/sensors/${id}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
  echo "${id}"
}

# Create CLIPTemperature sensor.
# Usage: id=$(ph_sensor_clip_temperature id name)
function ph_sensor_clip_temperature() {
  _ph_sensor_clip "${1}" "${2}" CLIPTemperature
}

# Create CLIPHumidity sensor.
# Usage: id=$(ph_sensor_clip_humidity id name)
function ph_sensor_clip_humidity() {
  _ph_sensor_clip "${1}" "${2}" CLIPHumidity
}

# Create CLIPPressure sensor.
# Usage: id=$(ph_sensor_clip_pressure id name)
function ph_sensor_clip_pressure() {
  _ph_sensor_clip "${1}" "${2}" CLIPPressure
}

# Create CLIPOpenClose sensor.
# Usage: id=$(ph_sensor_clip_openclose id name)
function ph_sensor_clip_openclose() {
  _ph_sensor_clip "${1}" "${2}" CLIPOpenClose
}

# Create MultiCLIP resourcelink.
# Usage: id=$(ph_sensor_multiclip id [id...])
function ph_sensor_multiclip() {
  ph delete "/resourcelinks/${1}" >/dev/null 2>&1
  local links="\"/sensors/${1}\""
  local -i one="${1}"
  shift
  for i in "${@}" ; do
    links="${links}, \"/sensors/${i}\""
  done
  local -i id=$(ph_unquote $(ph post "/resourcelinks" "{
    \"name\": \"homebridge-hue\",
    \"description\": \"multiclip\",
    \"classid\": 1,
    \"links\": [${links}]
  }"))
  [ $? -ne 0 ] && return 1
  _ph_info "/resourcelinks/${id}: multiclip"
  [ ${id} -ne ${one} ] && _ph_warn "/resourcelinks/${id}: not requested id ${one}"
  echo ${id}
}

# Create MultiLight resourcelink.
# Usage: id=$(ph_light_multilight id [id...])
function ph_light_multilight() {
  ph delete "/resourcelinks/${1}" >/dev/null 2>&1
  local links="\"/lights/${1}\""
  local -i one="${1}"
  shift
  for i in "${@}" ; do
    links="${links}, \"/lights/${i}\""
  done
  local -i id=$(ph_unquote $(ph post "/resourcelinks" "{
    \"name\": \"homebridge-hue\",
    \"description\": \"multilight\",
    \"classid\": 1,
    \"links\": [${links}]
  }"))
  [ $? -ne 0 ] && return 1
  _ph_info "/resourcelinks/${id}: multilight"
  [ ${id} -ne ${one} ] && _ph_warn "/resourcelinks/${id}: not requested id ${one}"
  echo ${id}
}

# ===== ZIGBEE SENSORS =========================================================

# Set sensor name.
# Usage: ph_sensor_name id name
function ph_sensor_name() {
  ph put "/sensors/${1}" "{
    \"name\": \"${2}\"
  }"
  [ $? -eq 0 ] || return 1
  local type=$(ph_unquote $(ph get "/sensors/${1}/type"))
  _ph_info "/sensors/${1}: ${type} \"${2}\""
}

# Set Hue Motion presence sensor name, sensitivity, and resourcelink.
# Hue app v2 expects a resourcelink before it shows Hue Motion status.
# Usage: ph_sensor_presence id name [sensitivity]
function ph_sensor_presence() {
  local -i id

  ph_sensor_name "${1}" "${2}"
  [ $? -ne 0 ] && return 1
  ph put "/sensors/${1}/config" "{
    \"sensitivity\": ${3:-2}
  }"
  [ $? -eq 0 ] || return 1
  if [ "${_ph_model}" != "deCONZ" ] ; then
    id=$(ph_unquote $(ph post /resourcelinks "{
      \"name\": \"${2}\",
      \"classid\": 10010,
      \"links\": [ \"/sensors/${1}\" ]
    }"))
    _ph_info "/resourcelinks/${id}: ${2}"
  fi
}

# Set Hue Motion lightlevel sensor name and thresholds.
# Usage: ph_sensor_lightlevel id name [tholddark tholdoffset]
function ph_sensor_lightlevel() {
  ph_sensor_name "${1}" "${2}"
  [ $? -eq 0 ] || return 1
  ph put "/sensors/${1}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
}

# Set Hue Motion temperature sensor name and offset.
# Usage: ph_sensor_temperature id name [offset]
function ph_sensor_temperature() {
  ph_sensor_name "${1}" "${2}"
  [ $? -eq 0 ] || return 1
  [ "${_ph_model}" == "deCONZ" ] || return 0
  ph put "/sensors/${1}/config" "{
    \"offset\": ${3:-0}
  }"
}
